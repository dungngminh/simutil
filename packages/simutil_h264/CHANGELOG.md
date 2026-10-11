# Changelog

## 0.1.0

- Initial release: `H264Decoder` decodes Annex-B H.264 access units into a
  Flutter texture with VideoToolbox (macOS), Media Foundation (Windows) and
  libavcodec (Linux).
- `H264Decoder.decodeFunction` exposes the native C `decode` entry point for
  feeding frames from a worker isolate through `dart:ffi`.
- Drops delta frames when the decoder falls behind and asks for a key frame
  through `onKeyFrameNeeded`.
