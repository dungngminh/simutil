// H.264 Annex-B access units decoded with Media Foundation into Flutter
// pixel-buffer textures.

#include "include/simutil_h264/simutil_h264_plugin_c_api.h"

#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mftransform.h>
#include <wmcodecdsp.h>
#include <wrl/client.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <algorithm>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;

constexpr uint8_t kBlack[4] = {0, 0, 0, 255};

constexpr char kDecodeChannel[] = "simutil/h264/decode";

// Queued access units before delta frames are dropped until a key frame.
constexpr size_t kMaxBacklog = 6;

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
  size_t width = 0;
  size_t height = 0;
};

uint8_t Clamp(int value) {
  return static_cast<uint8_t>(std::clamp(value, 0, 255));
}

// Decodes one stream on a worker thread; frames are triple-buffered between
// the worker and the raster thread.
class H264Decoder {
 public:
  explicit H264Decoder(flutter::TextureRegistrar* textures)
      : textures_(textures),
        texture_(flutter::PixelBufferTexture(
            [this](size_t, size_t) { return CopyPixels(); })) {
    id_ = textures_->RegisterTexture(&texture_);
    worker_ = std::thread([this] { Run(); });
  }

  int64_t id() const { return id_; }

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

  // Joins the worker; |this| is deleted once the engine drops the texture.
  void Dispose() {
    {
      std::lock_guard<std::mutex> lock(queue_mutex_);
      stopping_ = true;
    }
    queue_ready_.notify_one();
    worker_.join();
    textures_->UnregisterTexture(id_, [this] { delete this; });
  }

 private:
  void Run() {
    const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    const bool started = SUCCEEDED(MFStartup(MF_VERSION, MFSTARTUP_LITE));
    const bool ready = started && CreateDecoder();
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
      if (ready) DecodeNow(data);
    }
    decoder_.Reset();
    if (started) MFShutdown();
    if (SUCCEEDED(com)) CoUninitialize();
  }

  bool CreateDecoder() {
    if (FAILED(CoCreateInstance(CLSID_CMSH264DecoderMFT, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&decoder_)))) {
      return false;
    }
    ComPtr<IMFAttributes> attributes;
    if (SUCCEEDED(decoder_->GetAttributes(&attributes))) {
      attributes->SetUINT32(MF_LOW_LATENCY, TRUE);
    }
    ComPtr<IMFMediaType> input;
    if (FAILED(MFCreateMediaType(&input))) return false;
    input->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    input->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    if (FAILED(decoder_->SetInputType(0, input.Get(), 0))) return false;
    return SetOutputType();
  }

  // Picks NV12 and reads its layout; called again on every stream change.
  bool SetOutputType() {
    for (DWORD i = 0;; i++) {
      ComPtr<IMFMediaType> type;
      if (FAILED(decoder_->GetOutputAvailableType(0, i, &type))) return false;
      GUID subtype;
      if (FAILED(type->GetGUID(MF_MT_SUBTYPE, &subtype)) ||
          subtype != MFVideoFormat_NV12) {
        continue;
      }
      if (FAILED(decoder_->SetOutputType(0, type.Get(), 0))) return false;
      UINT32 width = 0, height = 0;
      MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &width, &height);
      coded_height_ = height;
      stride_ = MFGetAttributeUINT32(type.Get(), MF_MT_DEFAULT_STRIDE, width);
      MFVideoArea area = {};
      if (SUCCEEDED(type->GetBlob(MF_MT_MINIMUM_DISPLAY_APERTURE,
                                  reinterpret_cast<UINT8*>(&area),
                                  sizeof(area), nullptr))) {
        width = static_cast<UINT32>(area.Area.cx);
        height = static_cast<UINT32>(area.Area.cy);
      }
      width_ = width;
      height_ = height;
      return true;
    }
  }

  void DecodeNow(const std::vector<uint8_t>& data) {
    ComPtr<IMFMediaBuffer> buffer;
    ComPtr<IMFSample> sample;
    BYTE* dst = nullptr;
    const DWORD size = static_cast<DWORD>(data.size());
    if (FAILED(MFCreateMemoryBuffer(size, &buffer)) ||
        FAILED(buffer->Lock(&dst, nullptr, nullptr))) {
      return;
    }
    memcpy(dst, data.data(), data.size());
    buffer->Unlock();
    buffer->SetCurrentLength(size);
    if (FAILED(MFCreateSample(&sample)) ||
        FAILED(sample->AddBuffer(buffer.Get()))) {
      return;
    }
    if (decoder_->ProcessInput(0, sample.Get(), 0) == MF_E_NOTACCEPTING) {
      DrainOutput();
      decoder_->ProcessInput(0, sample.Get(), 0);
    }
    DrainOutput();
  }

  void DrainOutput() {
    while (true) {
      MFT_OUTPUT_STREAM_INFO info = {};
      ComPtr<IMFSample> sample;
      ComPtr<IMFMediaBuffer> buffer;
      if (FAILED(decoder_->GetOutputStreamInfo(0, &info)) ||
          FAILED(MFCreateSample(&sample)) ||
          FAILED(MFCreateMemoryBuffer(info.cbSize, &buffer)) ||
          FAILED(sample->AddBuffer(buffer.Get()))) {
        return;
      }
      MFT_OUTPUT_DATA_BUFFER output = {};
      output.pSample = sample.Get();
      DWORD status = 0;
      const HRESULT result = decoder_->ProcessOutput(0, 1, &output, &status);
      if (output.pEvents) output.pEvents->Release();
      if (result == MF_E_TRANSFORM_STREAM_CHANGE) {
        if (!SetOutputType()) return;
        continue;
      }
      if (FAILED(result)) return;  // MF_E_TRANSFORM_NEED_MORE_INPUT
      Publish(buffer.Get());
    }
  }

  // NV12 → RGBA (BT.601 limited range) into the back buffer, then swaps it
  // in for the raster thread.
  void Publish(IMFMediaBuffer* buffer) {
    BYTE* src = nullptr;
    DWORD length = 0;
    if (FAILED(buffer->Lock(&src, nullptr, &length))) return;
    const size_t stride = stride_;
    const size_t width = width_;
    const size_t height = height_;
    if (length < stride * coded_height_ * 3 / 2) {
      buffer->Unlock();
      return;
    }
    const BYTE* uv = src + stride * coded_height_;
    back_.pixels.resize(width * height * 4);
    back_.width = width;
    back_.height = height;
    uint8_t* out = back_.pixels.data();
    for (size_t y = 0; y < height; y++) {
      const BYTE* luma = src + y * stride;
      const BYTE* chroma = uv + (y / 2) * stride;
      for (size_t x = 0; x < width; x++) {
        const size_t pair = x & ~size_t{1};
        const int c = 298 * (luma[x] - 16) + 128;
        const int d = chroma[pair] - 128;
        const int e = chroma[pair + 1] - 128;
        *out++ = Clamp((c + 409 * e) >> 8);
        *out++ = Clamp((c - 100 * d - 208 * e) >> 8);
        *out++ = Clamp((c + 516 * d) >> 8);
        *out++ = 255;
      }
    }
    buffer->Unlock();
    {
      std::lock_guard<std::mutex> lock(pixels_mutex_);
      std::swap(back_, ready_);
      dirty_ = true;
    }
    textures_->MarkTextureFrameAvailable(id_);
  }

  const FlutterDesktopPixelBuffer* CopyPixels() {
    std::lock_guard<std::mutex> lock(pixels_mutex_);
    if (dirty_) {
      std::swap(ready_, display_);
      dirty_ = false;
      frames_shown_++;
    }
    if (display_.pixels.empty()) {
      pixel_buffer_.buffer = kBlack;
      pixel_buffer_.width = 1;
      pixel_buffer_.height = 1;
    } else {
      pixel_buffer_.buffer = display_.pixels.data();
      pixel_buffer_.width = display_.width;
      pixel_buffer_.height = display_.height;
    }
    return &pixel_buffer_;
  }

  flutter::TextureRegistrar* textures_;
  flutter::TextureVariant texture_;
  int64_t id_ = -1;
  std::thread worker_;

  std::mutex queue_mutex_;
  std::condition_variable queue_ready_;
  std::deque<std::vector<uint8_t>> queue_;
  bool stopping_ = false;
  bool waiting_for_key_ = false;

  ComPtr<IMFTransform> decoder_;
  UINT32 coded_height_ = 0;
  UINT32 stride_ = 0;
  UINT32 width_ = 0;
  UINT32 height_ = 0;

  std::mutex pixels_mutex_;
  Frame back_;
  Frame ready_;
  Frame display_;
  bool dirty_ = false;
  int64_t frames_shown_ = 0;
  FlutterDesktopPixelBuffer pixel_buffer_ = {};
};

// `simutil/h264` methods: create → textureId, frames({id}) → frames shown,
// dispose({id}). Access units arrive on the binary channel
// `simutil/h264/decode` as `int64 LE id` + Annex-B bytes; the reply is `[1]`
// when frames were dropped and the sender should send a key frame.
class SimutilH264Plugin : public flutter::Plugin {
 public:
  SimutilH264Plugin(flutter::TextureRegistrar* textures,
                    flutter::BinaryMessenger* messenger)
      : textures_(textures), messenger_(messenger) {
    messenger_->SetMessageHandler(
        kDecodeChannel, [this](const uint8_t* message, size_t size,
                               const flutter::BinaryReply& reply) {
          static const uint8_t kNeedKey[1] = {1};
          if (DecodeMessage(message, size)) {
            reply(kNeedKey, 1);
          } else {
            reply(nullptr, 0);
          }
        });
  }

  ~SimutilH264Plugin() override {
    messenger_->SetMessageHandler(kDecodeChannel, nullptr);
  }

  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "create") {
      auto* decoder = new H264Decoder(textures_);
      decoders_[decoder->id()] = decoder;
      result->Success(flutter::EncodableValue(decoder->id()));
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("args", "id required");
      return;
    }
    const auto id = args->find(flutter::EncodableValue("id"));
    const auto decoder = id == args->end()
                             ? decoders_.end()
                             : decoders_.find(id->second.LongValue());
    if (call.method_name() == "frames") {
      result->Success(flutter::EncodableValue(
          decoder != decoders_.end() ? decoder->second->frames_shown()
                                     : int64_t{0}));
    } else if (call.method_name() == "dispose") {
      if (decoder != decoders_.end()) {
        decoder->second->Dispose();
        decoders_.erase(decoder);
      }
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

 private:
  bool DecodeMessage(const uint8_t* message, size_t size) {
    if (!message || size <= 8) return false;
    uint64_t id = 0;
    for (int i = 7; i >= 0; i--) id = (id << 8) | message[i];
    const auto decoder = decoders_.find(static_cast<int64_t>(id));
    return decoder != decoders_.end() &&
           decoder->second->Decode(message + 8, size - 8);
  }

  flutter::TextureRegistrar* textures_;
  flutter::BinaryMessenger* messenger_;
  std::map<int64_t, H264Decoder*> decoders_;
};

}  // namespace

void SimutilH264PluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar_ref) {
  auto* registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref);
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "simutil/h264",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin =
      std::make_unique<SimutilH264Plugin>(registrar->texture_registrar(),
                                          registrar->messenger());
  channel->SetMethodCallHandler(
      [handler = plugin.get()](const auto& call, auto result) {
        handler->Handle(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}
