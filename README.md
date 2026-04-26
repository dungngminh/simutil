<p align="center">
  <img src="art/simutil.png" alt="SimUtil" width="200" />
</p>
<h1 align="center">SimUtil</h1>

<p align="center">
  <strong>A terminal UI for launching Android Emulators / iOS Simulators</strong><br>
  <strong>Launch, connect, manage your devices and more — all from the terminal</strong>
</p>

<p align="center">
  <a href="https://www.producthunt.com/products/simutil?embed=true&amp;utm_source=badge-featured&amp;utm_medium=badge&amp;utm_campaign=badge-simutil" target="_blank" rel="noopener noreferrer"><img alt="SimUtil - Terminal UI for iOS Simulators and Android Emulators | Product Hunt" width="250" height="54" src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1111003&amp;theme=light&amp;t=1774974338508"></a>
</p>
<p align="center">
  <img src="https://img.shields.io/github/stars/dungngminh/simutil" alt="GitHub Repo stars" />
  <a href="https://github.com/dungngminh/simutil/actions/workflows/ci.yaml"><img src="https://github.com/dungngminh/simutil/actions/workflows/ci.yaml/badge.svg" alt="Build" /></a>
  <a href="https://github.com/dungngminh/simutil/releases/latest"><img src="https://img.shields.io/github/v/release/dungngminh/simutil" alt="GitHub release" /></a>
</p>

Browse your available emulators and simulators side-by-side, launch with custom options and connect to physical devices wirelessly.

Simutil is written with [Nocterm](https://nocterm.dev/), a terminal UI framework for Dart with similar syntax to Flutter.

![Simutil Showcase](art/showcase.png)

## Features

- **One-Key Launch** — Start any device with `Enter`, no need to open Android Studio or Xcode
- **Android Launch Options** — Provide launch option for Android Emulators: Normal, Cold Boot, No Audio, or Cold Boot + No Audio,...
- **Shutdown device** — Shutdown simulators/emulators.
- **Logcat** — View logcat output of Android emulators / devices, support filtering.
- **ADB Tools Built-in** — Connect to physical Android devices wirelessly:
  - Connect via IP address
  - Pair with 6-digit code (Android 11+)
  - QR code pairing (Android 11+)

## Installation

### Binary Install

```bash
curl -fsSL https://raw.githubusercontent.com/dungngminh/simutil/main/install.sh | bash
```

### Binary Install (Windows PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/dungngminh/simutil/main/install.ps1 | iex"
```

### Using Homebrew (macOS/Linux)

```bash
brew tap dungngminh/simutil
brew install simutil
```

### From pub.dev

```bash
dart pub global activate simutil
```

### From source

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
- [x] Windows

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
