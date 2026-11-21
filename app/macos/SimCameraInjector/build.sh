#!/bin/bash
# Builds libSimCameraInjector.dylib for the iOS Simulator (arm64 + x86_64)
# into $1. Adapted from serve-sim's Sources/SimCameraInjector/build.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$1"
DYLIB="$OUT_DIR/libSimCameraInjector.dylib"
mkdir -p "$OUT_DIR"

# Xcode's macOS build environment (SDKROOT, deployment target, ...) must not
# leak into an iphonesimulator compile.
unset SDKROOT MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET

newest_source=$(ls -t "$HERE"/*.m "$HERE"/*.h "$HERE"/include/*.h "$0" | head -1)
if [[ -f "$DYLIB" && "$DYLIB" -nt "$newest_source" ]]; then
  exit 0
fi

SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator clang \
    -arch arm64 -arch x86_64 \
    -mios-simulator-version-min=15.0 \
    -isysroot "$SDK" \
    -dynamiclib \
    -fobjc-arc \
    -fmodules \
    -fobjc-weak \
    -framework Foundation \
    -framework UIKit \
    -framework AVFoundation \
    -framework CoreImage \
    -framework CoreMedia \
    -framework CoreMotion \
    -framework CoreVideo \
    -framework CoreGraphics \
    -framework IOSurface \
    -framework QuartzCore \
    -install_name "@rpath/libSimCameraInjector.dylib" \
    -o "$DYLIB" \
    "$HERE/SimCameraInjector.m" \
    "$HERE/SimCamLog.m" \
    "$HERE/SimCamFakes.m" \
    "$HERE/SimCamFrameSource.m" \
    "$HERE/SimCamSwizzles.m"
