// Adapted from serve-sim (https://github.com/EvanBacon/serve-sim),
// Copyright Evan Bacon, Apache License 2.0: Sources/SimCameraHelper/main.m.
// The process globals became instance state so several simulators can each
// have a feed; the control socket, placeholder source and main() are gone.

#import "SimCameraFeed.h"

#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <IOSurface/IOSurface.h>

#include <fcntl.h>
#include <mach/mach_time.h>
#include <stdatomic.h>
#include <sys/mman.h>
#include <unistd.h>

#include "../SimCameraInjector/include/SimCamShared.h"

static const CGBitmapInfo kSimCamBGRA =
    (CGBitmapInfo)kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little;

static uint64_t MachAbsToNs(uint64_t t) {
  static mach_timebase_info_data_t tb = {0, 0};
  if (tb.denom == 0) mach_timebase_info(&tb);
  return t * tb.numer / tb.denom;
}

static NSArray<AVCaptureDevice *> *HostCameras(void) {
  NSArray<AVCaptureDeviceType> *types;
  if (@available(macOS 14.0, *)) {
    types = @[
      AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternal,
      AVCaptureDeviceTypeContinuityCamera
    ];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    types = @[ AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown ];
#pragma clang diagnostic pop
  }
  return [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:types
                                   mediaType:AVMediaTypeVideo
                                    position:AVCaptureDevicePositionUnspecified]
      .devices;
}

@interface SimCameraFeed () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation SimCameraFeed {
  SimCamShmHeader *_header;
  SimCamSurfaceTable *_table;
  IOSurfaceRef _surfaces[SIMCAM_SURFACE_RING];
  uint32_t _writeIndex;
  uint32_t _width;
  uint32_t _height;
  atomic_uint_fast64_t _frameSeq;
  atomic_bool _stopped;
  dispatch_queue_t _sourceQueue;  // serial; owns source lifecycle
  // Serializes PublishFrame against -stop releasing the ring.
  NSLock *_publishLock;

  AVCaptureSession *_webcamSession;
  dispatch_queue_t _webcamQueue;
  uint8_t *_webcamScratch;
  size_t _webcamScratchSize;

  dispatch_queue_t _videoQueue;
  atomic_bool _videoCancelled;
  dispatch_semaphore_t _videoStopped;  // signaled when the loop exits
}

- (nullable instancetype)initWithShmName:(NSString *)shmName {
  if (!(self = [super init])) return nil;
  _shmName = [shmName copy];
  _width = SIMCAM_DEFAULT_WIDTH;
  _height = SIMCAM_DEFAULT_HEIGHT;
  _sourceQueue = dispatch_queue_create("simutil.camera.source", DISPATCH_QUEUE_SERIAL);
  _publishLock = [NSLock new];
  if (![self openShm]) {
    [self releaseSurfaces];
    return nil;
  }
  return self;
}

- (void)dealloc {
  [self stop];
  free(_webcamScratch);
}

#pragma mark - Shm + surfaces

- (BOOL)createSurfaces {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSDictionary *props = @{
    (id)kIOSurfaceWidth : @(_width),
    (id)kIOSurfaceHeight : @(_height),
    (id)kIOSurfaceBytesPerElement : @4,
    (id)kIOSurfacePixelFormat : @((uint32_t)kCVPixelFormatType_32BGRA),
    // Global so the simulator process can resolve the surface by ID.
    (id)kIOSurfaceIsGlobal : @YES,
  };
#pragma clang diagnostic pop
  for (uint32_t i = 0; i < SIMCAM_SURFACE_RING; i++) {
    IOSurfaceRef s = IOSurfaceCreate((__bridge CFDictionaryRef)props);
    if (!s) return NO;
    _surfaces[i] = s;
    _table->ids[i] = IOSurfaceGetID(s);
  }
  _table->surfaceCount = SIMCAM_SURFACE_RING;
  _table->latestIndex = 0;
  return YES;
}

- (void)releaseSurfaces {
  for (uint32_t i = 0; i < SIMCAM_SURFACE_RING; i++) {
    if (_surfaces[i]) {
      CFRelease(_surfaces[i]);
      _surfaces[i] = NULL;
    }
  }
}

- (BOOL)openShm {
  const char *name = _shmName.UTF8String;
  size_t size = (size_t)SimCamControlSize();
  shm_unlink(name);
  int fd = shm_open(name, O_CREAT | O_RDWR, 0644);
  if (fd < 0) return NO;
  if (ftruncate(fd, (off_t)size) < 0) {
    close(fd);
    return NO;
  }
  void *map = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  close(fd);
  if (map == MAP_FAILED) return NO;
  memset(map, 0, size);
  _header = (SimCamShmHeader *)map;
  _table = (SimCamSurfaceTable *)((uint8_t *)map + sizeof(SimCamShmHeader));
  if (![self createSurfaces]) {
    munmap(map, size);
    _header = NULL;
    _table = NULL;
    shm_unlink(name);
    return NO;
  }
  _header->magic = SIMCAM_SHM_MAGIC;
  _header->version = 2;
  _header->width = _width;
  _header->height = _height;
  _header->pixelFormat = SIMCAM_PIXEL_BGRA;
  _header->bytesPerRow = (uint32_t)IOSurfaceGetBytesPerRow(_surfaces[0]);
  _header->pixelByteSize = (uint64_t)_width * _height * 4;
  _header->mirrorMode = SIMCAM_MIRROR_UNSET;  // dylib falls back to env
  return YES;
}

// Publish a fully-prepared BGRA frame (_width x _height, packed at _width*4
// bytes per row) into the next free ring surface, so latestIndex/frameSeq
// stay coherent for the dylib's tear-detection check.
- (void)publishFrame:(const uint8_t *)bgra {
  if (!bgra) return;
  [_publishLock lock];
  if (!_header || !_table || _table->surfaceCount == 0) {
    [_publishLock unlock];
    return;
  }
  uint32_t count = _table->surfaceCount;
  // Render into a surface the reader isn't holding and isn't the one it last
  // published, so an in-flight frame is never overwritten mid-read.
  uint32_t latest = _table->latestIndex;
  uint32_t idx = _writeIndex;
  BOOL found = NO;
  for (uint32_t tries = 0; tries < count; tries++) {
    idx = (idx + 1) % count;
    if (idx == latest || !_surfaces[idx]) continue;
    if (!IOSurfaceIsInUse(_surfaces[idx])) {
      found = YES;
      break;
    }
  }
  if (!found) {
    [_publishLock unlock];
    return;
  }
  IOSurfaceRef surface = _surfaces[idx];
  _writeIndex = idx;
  IOSurfaceLock(surface, 0, NULL);
  uint8_t *dst = (uint8_t *)IOSurfaceGetBaseAddress(surface);
  size_t dstStride = IOSurfaceGetBytesPerRow(surface);
  size_t srcStride = (size_t)_width * 4;
  if (dstStride == srcStride) {
    memcpy(dst, bgra, srcStride * _height);
  } else {
    for (uint32_t y = 0; y < _height; y++) {
      memcpy(dst + (size_t)y * dstStride, bgra + (size_t)y * srcStride, srcStride);
    }
  }
  IOSurfaceUnlock(surface, 0, NULL);

  _table->latestIndex = idx;
  _header->timestampNs = MachAbsToNs(mach_absolute_time());
  atomic_thread_fence(memory_order_release);
  uint64_t next = atomic_fetch_add(&_frameSeq, 1) + 1;
  atomic_store_explicit(&_header->frameSeq, next, memory_order_release);
  [_publishLock unlock];
}

#pragma mark - Webcam source

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)webcams {
  NSMutableArray *out = [NSMutableArray array];
  for (AVCaptureDevice *d in HostCameras()) {
    [out addObject:@{@"id" : d.uniqueID, @"name" : d.localizedName}];
  }
  return out;
}

static AVCaptureDevice *PickWebcamDevice(NSString *idOrName) {
  NSArray<AVCaptureDevice *> *devices = HostCameras();
  if (!idOrName.length) {
    for (AVCaptureDevice *d in devices)
      if (d.position == AVCaptureDevicePositionFront) return d;
    return devices.firstObject;
  }
  for (AVCaptureDevice *d in devices)
    if ([d.uniqueID isEqualToString:idOrName]) return d;
  for (AVCaptureDevice *d in devices)
    if ([d.localizedName.lowercaseString containsString:idOrName.lowercaseString]) return d;
  return nil;
}

- (void)captureOutput:(AVCaptureOutput *)out
    didOutputSampleBuffer:(CMSampleBufferRef)sb
           fromConnection:(AVCaptureConnection *)conn {
  CVImageBufferRef pb = CMSampleBufferGetImageBuffer(sb);
  if (!pb) return;
  if (CVPixelBufferGetPixelFormatType(pb) != kCVPixelFormatType_32BGRA) return;
  CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
  size_t srcW = CVPixelBufferGetWidth(pb);
  size_t srcH = CVPixelBufferGetHeight(pb);
  size_t srcStride = CVPixelBufferGetBytesPerRow(pb);
  void *src = CVPixelBufferGetBaseAddress(pb);
  size_t need = (size_t)_width * _height * 4;
  if (_webcamScratchSize < need) {
    free(_webcamScratch);
    _webcamScratch = malloc(need);
    _webcamScratchSize = need;
  }
  vImage_Buffer s = {src, srcH, srcW, srcStride};
  vImage_Buffer d = {_webcamScratch, _height, _width, (size_t)_width * 4};
  vImage_Error verr = vImageScale_ARGB8888(&s, &d, NULL, kvImageHighQualityResampling);
  CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
  if (verr == kvImageNoError) [self publishFrame:_webcamScratch];
}

- (nullable NSString *)startWebcam:(NSString *)deviceArg {
  AVCaptureDevice *device = PickWebcamDevice(deviceArg);
  if (!device) return @"No matching camera";
  NSError *e = nil;
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&e];
  if (!input) return e.localizedDescription ?: @"Could not open the camera";
  AVCaptureSession *sess = [AVCaptureSession new];
  sess.sessionPreset = AVCaptureSessionPreset1280x720;
  if (![sess canAddInput:input]) return @"The camera is in use";
  [sess addInput:input];
  AVCaptureVideoDataOutput *out = [AVCaptureVideoDataOutput new];
  out.alwaysDiscardsLateVideoFrames = YES;
  out.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
  if (!_webcamQueue) {
    _webcamQueue = dispatch_queue_create("simutil.camera.webcam", DISPATCH_QUEUE_SERIAL);
  }
  [out setSampleBufferDelegate:self queue:_webcamQueue];
  if (![sess canAddOutput:out]) return @"The camera has no video output";
  [sess addOutput:out];
  [sess startRunning];
  _webcamSession = sess;
  return nil;
}

- (void)stopWebcam {
  if (!_webcamSession) return;
  [_webcamSession stopRunning];
  _webcamSession = nil;
  // Wait out a frame still being written on the delegate queue.
  if (_webcamQueue) dispatch_sync(_webcamQueue, ^{});
}

#pragma mark - Image source

- (nullable NSString *)startImage:(NSString *)path {
  if (!path.length) return @"The image source needs a file";
  CGImageSourceRef src =
      CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
  if (!src) return @"Could not open the image";
  CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
  CFRelease(src);
  if (!img) return @"Could not decode the image";

  size_t bpr = (size_t)_width * 4;
  uint8_t *buf = calloc(1, bpr * _height);
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(buf, _width, _height, 8, bpr, cs,
                                           kSimCamBGRA);
  CGColorSpaceRelease(cs);
  size_t iw = CGImageGetWidth(img), ih = CGImageGetHeight(img);
  double sx = (double)_width / iw, sy = (double)_height / ih;
  // Aspect-fit file sources so the full source frame remains visible.
  double s = MIN(sx, sy);
  double dw = iw * s, dh = ih * s;
  CGContextDrawImage(ctx, CGRectMake((_width - dw) / 2.0, (_height - dh) / 2.0, dw, dh), img);
  CGContextRelease(ctx);
  CGImageRelease(img);

  [self publishFrame:buf];
  free(buf);
  return nil;
}

#pragma mark - Video source (looping playback via AVAssetReader)

// Looping AVAsset playback at native FPS. Frames are decoded as BGRA on a
// background queue, aspect-fit into the ring, then paced against the track's
// presentation timestamps so playback runs at real time. When the reader
// completes it is recreated with a fresh wall-clock anchor.

static AVAssetReaderTrackOutput *MakeVideoOutput(AVAssetReader **outReader, AVAssetTrack *track,
                                                 NSString **errOut) {
  NSError *e = nil;
  AVAsset *asset = track.asset;
  AVAssetReader *reader = asset ? [AVAssetReader assetReaderWithAsset:asset error:&e] : nil;
  if (!reader) {
    if (errOut) *errOut = e.localizedDescription ?: @"AVAssetReader init failed";
    return nil;
  }
  AVAssetReaderTrackOutput *out = [AVAssetReaderTrackOutput
      assetReaderTrackOutputWithTrack:track
                       outputSettings:@{
                         (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                         (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
                       }];
  out.alwaysCopiesSampleData = NO;
  if (![reader canAddOutput:out]) {
    if (errOut) *errOut = @"reader rejected BGRA output";
    return nil;
  }
  [reader addOutput:out];
  if (![reader startReading]) {
    if (errOut) *errOut = reader.error.localizedDescription ?: @"reader failed to start";
    return nil;
  }
  *outReader = reader;
  return out;
}

// Aspect-fit a source pixel buffer into a new BGRA buffer of the ring size;
// the caller frees it.
- (uint8_t *)renderPixelBuffer:(CVPixelBufferRef)pb {
  size_t srcW = CVPixelBufferGetWidth(pb);
  size_t srcH = CVPixelBufferGetHeight(pb);
  if (srcW == 0 || srcH == 0) return NULL;
  CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
  uint8_t *src = CVPixelBufferGetBaseAddress(pb);
  size_t srcBPR = CVPixelBufferGetBytesPerRow(pb);
  if (!src) {
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    return NULL;
  }

  size_t bpr = (size_t)_width * 4;
  uint8_t *out = calloc(1, bpr * _height);
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(out, _width, _height, 8, bpr, cs,
                                           kSimCamBGRA);
  CGColorSpaceRelease(cs);

  CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, src, srcBPR * srcH, NULL);
  CGColorSpaceRef imgCs = CGColorSpaceCreateDeviceRGB();
  CGImageRef img = CGImageCreate(srcW, srcH, 8, 32, srcBPR, imgCs,
                                 kSimCamBGRA, dp, NULL,
                                 false, kCGRenderingIntentDefault);
  CGColorSpaceRelease(imgCs);
  CGDataProviderRelease(dp);

  double sx = (double)_width / srcW, sy = (double)_height / srcH;
  // Keep video file playback letterboxed instead of cropping the source.
  double s = MIN(sx, sy);
  double dw = srcW * s, dh = srcH * s;
  CGContextDrawImage(ctx, CGRectMake((_width - dw) / 2.0, (_height - dh) / 2.0, dw, dh), img);
  CGImageRelease(img);
  CGContextRelease(ctx);
  CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
  return out;
}

- (void)runVideoLoop:(NSString *)path stopped:(dispatch_semaphore_t)stopped {
  AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
#pragma clang diagnostic pop
  while (track && !atomic_load(&_videoCancelled)) {
    NSString *err = nil;
    AVAssetReader *reader = nil;
    AVAssetReaderTrackOutput *out = MakeVideoOutput(&reader, track, &err);
    if (!out) {
      NSLog(@"[SimCamera] video reader failed: %@", err);
      break;
    }

    uint64_t loopStartNs = MachAbsToNs(mach_absolute_time());
    while (!atomic_load(&_videoCancelled)) {
      CMSampleBufferRef sb = [out copyNextSampleBuffer];
      if (!sb) break;  // end of track or read error → loop or exit
      CMTime pts = CMSampleBufferGetPresentationTimeStamp(sb);
      CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sb);
      uint8_t *frame = pb ? [self renderPixelBuffer:pb] : NULL;
      if (frame) {
        // Pace against wall clock: don't publish until the frame's PTS has
        // caught up, in 100ms slices so cancellation stays responsive.
        if (CMTIME_IS_VALID(pts) && pts.timescale > 0) {
          uint64_t targetNs = loopStartNs + (uint64_t)((double)pts.value * 1e9 / pts.timescale);
          uint64_t nowNs = MachAbsToNs(mach_absolute_time());
          uint64_t sleepNs = targetNs > nowNs ? targetNs - nowNs : 0;
          while (sleepNs > 0 && !atomic_load(&_videoCancelled)) {
            uint64_t slice = sleepNs > 100000000ULL ? 100000000ULL : sleepNs;
            struct timespec ts = {
                .tv_sec = (time_t)(slice / 1000000000ULL),
                .tv_nsec = (long)(slice % 1000000000ULL),
            };
            nanosleep(&ts, NULL);
            sleepNs -= slice;
          }
        }
        [self publishFrame:frame];
        free(frame);
      }
      CFRelease(sb);
    }

    AVAssetReaderStatus status = reader.status;
    [reader cancelReading];
    if (status == AVAssetReaderStatusFailed) {
      NSLog(@"[SimCamera] video reader failed mid-loop: %@", reader.error.localizedDescription);
      break;
    }
    // Otherwise rewind by re-creating the reader on the next iteration.
  }
  dispatch_semaphore_signal(stopped);
}

- (nullable NSString *)startVideo:(NSString *)path {
  if (!path.length) return @"The video source needs a file";
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    return [NSString stringWithFormat:@"Video file not found: %@", path];
  }
  if (!_videoQueue) {
    _videoQueue = dispatch_queue_create("simutil.camera.video", DISPATCH_QUEUE_SERIAL);
  }
  atomic_store(&_videoCancelled, false);
  dispatch_semaphore_t stopped = dispatch_semaphore_create(0);
  _videoStopped = stopped;
  NSString *captured = [path copy];
  dispatch_async(_videoQueue, ^{
    [self runVideoLoop:captured stopped:stopped];
  });
  return nil;
}

- (void)stopVideoWaiting:(dispatch_time_t)deadline {
  if (!_videoStopped) return;
  atomic_store(&_videoCancelled, true);
  dispatch_semaphore_wait(_videoStopped, deadline);
  _videoStopped = nil;
}

#pragma mark - Switch / stop

- (void)stopActiveSource {
  [self stopWebcam];
  // A 1s cap so a wedged decoder cannot stall a hot-swap.
  [self stopVideoWaiting:dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)];
  _source = nil;
  _arg = nil;
}

- (nullable NSString *)switchToSource:(NSString *)source arg:(nullable NSString *)arg {
  __block NSString *err = nil;
  dispatch_sync(_sourceQueue, ^{
    if (atomic_load(&self->_stopped)) {
      err = @"The camera feed was stopped";
      return;
    }
    [self stopActiveSource];
    if ([source isEqualToString:@"webcam"]) {
      err = [self startWebcam:arg ?: @""];
    } else if ([source isEqualToString:@"image"]) {
      err = [self startImage:arg ?: @""];
    } else if ([source isEqualToString:@"video"]) {
      err = [self startVideo:arg ?: @""];
    } else {
      err = [NSString stringWithFormat:@"Unknown camera source %@", source];
    }
    if (!err) {
      self->_source = [source copy];
      self->_arg = [arg copy];
    }
  });
  return err;
}

- (void)stop {
  if (atomic_exchange(&_stopped, true)) return;
  // Unlink the name first: if a source teardown crashes, the name must not
  // stay resolvable.
  shm_unlink(_shmName.UTF8String);
  dispatch_sync(_sourceQueue, ^{
    [self stopWebcam];
    [self stopVideoWaiting:DISPATCH_TIME_FOREVER];
  });
  [_publishLock lock];
  [self releaseSurfaces];
  if (_header) munmap(_header, (size_t)SimCamControlSize());
  _header = NULL;
  _table = NULL;
  [_publishLock unlock];
}

@end
