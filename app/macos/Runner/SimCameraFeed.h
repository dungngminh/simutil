// Host side of the iOS Simulator camera: owns the shared-memory control
// region and IOSurface ring that libSimCameraInjector.dylib reads inside a
// simulator app, and renders a webcam, image or looping video into it.
//
// Adapted from serve-sim (https://github.com/EvanBacon/serve-sim),
// Copyright Evan Bacon, Apache License 2.0: Sources/SimCameraHelper/main.m,
// moved in-process (one instance per simulator, no control socket, no
// placeholder source).

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimCameraFeed : NSObject

/// Creates the shm region [shmName] (a POSIX name such as
/// `/simutil-cam-1a2b3c4d`) and its IOSurfaces; nil when that fails.
- (nullable instancetype)initWithShmName:(NSString *)shmName;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) NSString *shmName;
/// `webcam`, `image` or `video`; nil before the first switch.
@property(nonatomic, readonly, nullable) NSString *source;
/// Webcam unique ID / name, or the file path of the current source.
@property(nonatomic, readonly, nullable) NSString *arg;

/// Replaces the running source; returns an error message, nil on success.
- (nullable NSString *)switchToSource:(NSString *)source arg:(nullable NSString *)arg;

/// Stops the source, unlinks the shm name and frees the surfaces.
- (void)stop;

/// Host cameras as `{id, name}`.
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)webcams;

@end

NS_ASSUME_NONNULL_END
