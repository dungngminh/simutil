<h1 align="center">Simutil</h1>

<p align="center">
  <strong>A terminal UI for launching Android Emulators / iOS Simulators</strong><br>
  <strong>Launch, connect, manage your devices and more — all from the terminal</strong>
</p>

<p align="center">
  <a href="https://github.com/dungngminh/simutil/actions/workflows/ci.yaml"><img src="https://github.com/dungngminh/simutil/actions/workflows/ci.yaml/badge.svg" alt="Build" /></a>
  <a href="https://github.com/dungngminh/simutil/releases/latest"><img src="https://img.shields.io/github/v/release/dungngminh/simutil" alt="GitHub release" /></a>
</p>

Browse your available emulators and simulators side-by-side, launch with custom options and connect to physical devices wirelessly.

Simutil is written with [Nocterm](https://nocterm.dev/), a terminal UI framework for Dart with similar syntax to Flutter.

<video src="https://github.com/user-attachments/assets/abc83a10-6553-41e8-90e7-47a936f9485e" autoplay loop muted playsinline></video>

## Features

- **One-Key Launch** — Start any device with `Enter`, no need to open Android Studio or Xcode
- **Android Launch Options** — Provide launch option for Android Emulators: Normal, Cold Boot, No Audio, or Cold Boot + No Audio,...
- **ADB Tools Built-in** — Connect to physical Android devices wirelessly:
  - Connect via IP address
  - Pair with 6-digit code (Android 11+)
  - QR code pairing (Android 11+)

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/dungngminh/simutil/main/install.sh | bash
```

**Using Homebrew (macOS/Linux):**

```bash
brew tap dungngminh/simutil
brew install simutil
```

**From pub.dev:**

```bash
dart pub global activate simutil
```

**From source:**

```bash
git clone https://github.com/dungngminh/simutil.git
cd simutil
dart pub get
dart pub global activate --source path .
```

Then run:

```bash
simutil
```

## Supported platforms

- [x] macOS
- [x] Linux
- [ ] Windows


## Contributing

```bash
git clone https://github.com/dungngminh/simutil.git
cd simutil
dart pub get
dart run bin/simutil.dart   # Run locally

dart --enable-vm-service bin/simutil.dart # Run with hot reload
```

1. Fork this repository
2. Create a branch and make your changes
3. Open a Pull Request

## License

MIT — see [LICENSE](LICENSE)