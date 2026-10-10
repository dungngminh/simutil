// H.264 Annex-B access units decoded with libavcodec into Flutter
// pixel-buffer textures.

#include "include/simutil_h264/simutil_h264_plugin.h"

#include <flutter_linux/flutter_linux.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
}

#include <condition_variable>
#include <cstring>
#include <deque>
#include <functional>
#include <map>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

namespace {

const uint8_t kBlack[4] = {0, 0, 0, 255};

const char kDecodeChannel[] = "simutil/h264/decode";

// Queued access units before delta frames are dropped until a key frame.
const size_t kMaxBacklog = 6;

// Whether |data| holds an SPS or IDR slice; stops at the first slice.
bool IsKeyFrame(const uint8_t* data, size_t size) {
  for (size_t i = 0; i + 3 < size; i++) {
    if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1) {
      const int type = data[i + 3] & 0x1f;
      if (type == 5 || type == 7) return true;
      if (type == 1) return false;
      i += 2;
    }
  }
  return false;
}

struct Frame {
  std::vector<uint8_t> pixels;
  uint32_t width = 0;
  uint32_t height = 0;
};

// Decodes one stream on a worker thread; frames are triple-buffered between
// the worker and the raster thread.
class H264Decoder {
 public:
  explicit H264Decoder(std::function<void()> on_frame)
      : on_frame_(std::move(on_frame)) {
    worker_ = std::thread([this] { Run(); });
  }

  ~H264Decoder() { Stop(); }

  // Queues an access unit. When the worker falls behind, delta frames are
  // dropped until the next key frame; returns true when that starts.
  bool Decode(const uint8_t* data, size_t size) {
    {
      std::lock_guard<std::mutex> lock(queue_mutex_);
      if (waiting_for_key_ || queue_.size() >= kMaxBacklog) {
        if (!IsKeyFrame(data, size)) {
          const bool started = !waiting_for_key_;
          waiting_for_key_ = true;
          return started;
        }
        waiting_for_key_ = false;
      }
      queue_.emplace_back(data, data + size);
    }
    queue_ready_.notify_one();
    return false;
  }

  // Frames handed to the texture so far.
  int64_t frames_shown() {
    std::lock_guard<std::mutex> lock(pixels_mutex_);
    return frames_shown_;
  }

  void Stop() {
    {
      std::lock_guard<std::mutex> lock(queue_mutex_);
      stopping_ = true;
    }
    queue_ready_.notify_one();
    if (worker_.joinable()) worker_.join();
  }

  void CopyPixels(const uint8_t** buffer, uint32_t* width, uint32_t* height) {
    std::lock_guard<std::mutex> lock(pixels_mutex_);
    if (dirty_) {
      std::swap(ready_, display_);
      dirty_ = false;
      frames_shown_++;
    }
    if (display_.pixels.empty()) {
      *buffer = kBlack;
      *width = 1;
      *height = 1;
    } else {
      *buffer = display_.pixels.data();
      *width = display_.width;
      *height = display_.height;
    }
  }

 private:
  void Run() {
    const AVCodec* codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    AVCodecContext* context = codec ? avcodec_alloc_context3(codec) : nullptr;
    AVPacket* packet = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    bool ready = false;
    if (context && packet && frame) {
      context->flags |= AV_CODEC_FLAG_LOW_DELAY;
      context->thread_type = FF_THREAD_SLICE;
      ready = avcodec_open2(context, codec, nullptr) == 0;
    }
    SwsContext* scaler = nullptr;
    int scaler_width = 0, scaler_height = 0, scaler_format = -1;
    while (true) {
      std::vector<uint8_t> data;
      {
        std::unique_lock<std::mutex> lock(queue_mutex_);
        queue_ready_.wait(lock,
                          [this] { return stopping_ || !queue_.empty(); });
        if (stopping_) break;
        data = std::move(queue_.front());
        queue_.pop_front();
      }
      if (!ready) continue;
      const int size = static_cast<int>(data.size());
      data.resize(data.size() + AV_INPUT_BUFFER_PADDING_SIZE, 0);
      packet->data = data.data();
      packet->size = size;
      if (avcodec_send_packet(context, packet) != 0) continue;
      while (avcodec_receive_frame(context, frame) == 0) {
        if (!scaler || frame->width != scaler_width ||
            frame->height != scaler_height || frame->format != scaler_format) {
          sws_freeContext(scaler);
          scaler_width = frame->width;
          scaler_height = frame->height;
          scaler_format = frame->format;
          scaler = sws_getContext(
              scaler_width, scaler_height,
              static_cast<AVPixelFormat>(scaler_format), scaler_width,
              scaler_height, AV_PIX_FMT_RGBA, SWS_BILINEAR, nullptr, nullptr,
              nullptr);
        }
        if (!scaler) continue;
        back_.width = static_cast<uint32_t>(frame->width);
        back_.height = static_cast<uint32_t>(frame->height);
        back_.pixels.resize(static_cast<size_t>(back_.width) * back_.height * 4);
        uint8_t* planes[1] = {back_.pixels.data()};
        const int strides[1] = {frame->width * 4};
        sws_scale(scaler, frame->data, frame->linesize, 0, frame->height,
                  planes, strides);
        {
          std::lock_guard<std::mutex> lock(pixels_mutex_);
          std::swap(back_, ready_);
          dirty_ = true;
        }
        on_frame_();
      }
    }
    sws_freeContext(scaler);
    av_frame_free(&frame);
    av_packet_free(&packet);
    avcodec_free_context(&context);
  }

  std::function<void()> on_frame_;
  std::thread worker_;

  std::mutex queue_mutex_;
  std::condition_variable queue_ready_;
  std::deque<std::vector<uint8_t>> queue_;
  bool stopping_ = false;
  bool waiting_for_key_ = false;

  std::mutex pixels_mutex_;
  Frame back_;
  Frame ready_;
  Frame display_;
  bool dirty_ = false;
  int64_t frames_shown_ = 0;
};

}  // namespace

G_DECLARE_FINAL_TYPE(H264Texture, h264_texture, H264, TEXTURE,
                     FlPixelBufferTexture)

struct _H264Texture {
  FlPixelBufferTexture parent_instance;
  H264Decoder* decoder;
};

G_DEFINE_TYPE(H264Texture, h264_texture, fl_pixel_buffer_texture_get_type())

static gboolean h264_texture_copy_pixels(FlPixelBufferTexture* texture,
                                         const uint8_t** buffer,
                                         uint32_t* width, uint32_t* height,
                                         GError** error) {
  H264_TEXTURE(texture)->decoder->CopyPixels(buffer, width, height);
  return TRUE;
}

static void h264_texture_finalize(GObject* object) {
  delete H264_TEXTURE(object)->decoder;
  G_OBJECT_CLASS(h264_texture_parent_class)->finalize(object);
}

static void h264_texture_class_init(H264TextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = h264_texture_copy_pixels;
  G_OBJECT_CLASS(klass)->finalize = h264_texture_finalize;
}

static void h264_texture_init(H264Texture* self) {}

static H264Texture* h264_texture_new(FlTextureRegistrar* registrar) {
  H264Texture* self =
      H264_TEXTURE(g_object_new(h264_texture_get_type(), nullptr));
  self->decoder = new H264Decoder([registrar, self] {
    fl_texture_registrar_mark_texture_frame_available(registrar,
                                                      FL_TEXTURE(self));
  });
  return self;
}

#define SIMUTIL_H264_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), simutil_h264_plugin_get_type(), \
                              SimutilH264Plugin))

// `simutil/h264` methods: create → textureId, frames({id}) → frames shown,
// dispose({id}). Access units arrive on the binary channel
// `simutil/h264/decode` as `int64 LE id` + Annex-B bytes; the reply is `[1]`
// when frames were dropped and the sender should send a key frame.
struct _SimutilH264Plugin {
  GObject parent_instance;
  FlTextureRegistrar* registrar;
  std::map<int64_t, H264Texture*>* textures;
};

G_DEFINE_TYPE(SimutilH264Plugin, simutil_h264_plugin, g_object_get_type())

static void simutil_h264_plugin_handle_method_call(SimutilH264Plugin* self,
                                                   FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  if (strcmp(method, "create") == 0) {
    H264Texture* texture = h264_texture_new(self->registrar);
    fl_texture_registrar_register_texture(self->registrar,
                                          FL_TEXTURE(texture));
    const int64_t id = fl_texture_get_id(FL_TEXTURE(texture));
    (*self->textures)[id] = texture;
    g_autoptr(FlValue) result = fl_value_new_int(id);
    fl_method_call_respond_success(call, result, nullptr);
    return;
  }

  FlValue* args = fl_method_call_get_args(call);
  const bool is_map = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP;
  FlValue* id = is_map ? fl_value_lookup_string(args, "id") : nullptr;
  auto texture = id && fl_value_get_type(id) == FL_VALUE_TYPE_INT
                     ? self->textures->find(fl_value_get_int(id))
                     : self->textures->end();
  if (strcmp(method, "frames") == 0) {
    g_autoptr(FlValue) result = fl_value_new_int(
        texture != self->textures->end()
            ? texture->second->decoder->frames_shown()
            : 0);
    fl_method_call_respond_success(call, result, nullptr);
  } else if (strcmp(method, "dispose") == 0) {
    if (texture != self->textures->end()) {
      texture->second->decoder->Stop();
      fl_texture_registrar_unregister_texture(self->registrar,
                                              FL_TEXTURE(texture->second));
      g_object_unref(texture->second);
      self->textures->erase(texture);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

static void simutil_h264_plugin_dispose(GObject* object) {
  SimutilH264Plugin* self = SIMUTIL_H264_PLUGIN(object);
  if (self->textures) {
    for (auto& entry : *self->textures) {
      entry.second->decoder->Stop();
      g_object_unref(entry.second);
    }
    delete self->textures;
    self->textures = nullptr;
  }
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(simutil_h264_plugin_parent_class)->dispose(object);
}

static void simutil_h264_plugin_class_init(SimutilH264PluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = simutil_h264_plugin_dispose;
}

static void simutil_h264_plugin_init(SimutilH264Plugin* self) {
  self->textures = new std::map<int64_t, H264Texture*>();
}

static void decode_message_cb(FlBinaryMessenger* messenger,
                              const gchar* channel, GBytes* message,
                              FlBinaryMessengerResponseHandle* response_handle,
                              gpointer user_data) {
  SimutilH264Plugin* self = SIMUTIL_H264_PLUGIN(user_data);
  gsize size = 0;
  const uint8_t* bytes =
      message ? static_cast<const uint8_t*>(g_bytes_get_data(message, &size))
              : nullptr;
  bool need_key = false;
  if (self->textures && bytes && size > 8) {
    uint64_t id = 0;
    for (int i = 7; i >= 0; i--) id = (id << 8) | bytes[i];
    auto texture = self->textures->find(static_cast<int64_t>(id));
    if (texture != self->textures->end()) {
      need_key = texture->second->decoder->Decode(bytes + 8, size - 8);
    }
  }
  static const uint8_t kNeedKey[1] = {1};
  g_autoptr(GBytes) response =
      need_key ? g_bytes_new_static(kNeedKey, 1) : nullptr;
  fl_binary_messenger_send_response(messenger, response_handle, response,
                                    nullptr);
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  simutil_h264_plugin_handle_method_call(SIMUTIL_H264_PLUGIN(user_data), call);
}

void simutil_h264_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SimutilH264Plugin* plugin = SIMUTIL_H264_PLUGIN(
      g_object_new(simutil_h264_plugin_get_type(), nullptr));
  plugin->registrar = FL_TEXTURE_REGISTRAR(
      g_object_ref(fl_plugin_registrar_get_texture_registrar(registrar)));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "simutil/h264", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  fl_binary_messenger_set_message_handler_on_channel(
      fl_plugin_registrar_get_messenger(registrar), kDecodeChannel,
      decode_message_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
