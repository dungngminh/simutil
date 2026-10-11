# simutil_h264

Flutter plugin that decodes H.264 video natively into a Flutter texture, used by the SimUtil desktop app to stream device screens.

| Platform | Decoder |
| --- | --- |
| macOS | VideoToolbox |
| Windows | Media Foundation |
| Linux | libavcodec (FFmpeg) |

Part of [SimUtil](https://github.com/dungngminh/simutil).

## Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:simutil_h264/simutil_h264.dart';

final decoder = await H264Decoder.create();

// Show the frames.
Texture(textureId: decoder.textureId);

// Feed Annex-B access units (SPS/PPS first).
decoder.decode(accessUnit, onKeyFrameNeeded: requestKeyFrame);

await decoder.dispose();
```

To decode off the UI isolate, call the native `decode(int64_t id, const uint8_t* bytes, int64_t count)` at `await H264Decoder.decodeFunction` through `dart:ffi`.

## Linux

Needs the FFmpeg development packages, e.g. on Debian/Ubuntu:

```bash
sudo apt install libavcodec-dev libavutil-dev libswscale-dev
```
