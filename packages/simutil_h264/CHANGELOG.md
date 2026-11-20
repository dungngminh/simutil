# Changelog

## 0.2.1

- macOS: after a VideoToolbox decode error (for example after sleep or a
  GPU switch) the session is rebuilt and `decode` returns true once, so the
  caller requests a key frame, instead of the picture freezing until the
  source sends one on its own. A failing frame no longer counts twice
  against the backlog.

## 0.2.0

- `SharedFrameTexture` (macOS) shows packed RGB888 frames that another
  process writes into a shared file it maps, such as the Android emulator's
  gRPC MMAP transport, without a video codec.

## 0.1.0

- Initial release: `H264Decoder` decodes Annex-B H.264 access units into a
  Flutter texture with VideoToolbox (macOS), Media Foundation (Windows) and
  libavcodec (Linux).
- `H264Decoder.decodeFunction` exposes the native C `decode` entry point for
  feeding frames from a worker isolate through `dart:ffi`.
- Drops delta frames when the decoder falls behind and asks for a key frame
  through `onKeyFrameNeeded`.
