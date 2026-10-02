<p align="center">
  <img src="https://raw.githubusercontent.com/dungngminh/simutil/main/art/simutil.png" alt="SimUtil" width="200" />
</p>
<h1 align="center">SimUtil</h1>

A terminal UI and CLI for launching Android emulators and iOS simulators,
connecting devices over Wi-Fi ADB, viewing Logcat, and running your own tools
through YAML plugins. Runs on macOS, Linux, and Windows; iOS support requires
macOS with Xcode.

<p align="center">
  <img src="https://raw.githubusercontent.com/dungngminh/simutil/main/art/showcase.png" alt="SimUtil showcase" />
</p>

## Install

```bash
dart pub global activate simutil
```

Homebrew, a shell installer, and prebuilt binaries are listed in the
[main README](https://github.com/dungngminh/simutil#installation).

## Usage

```bash
simutil                       # open the TUI
simutil list                  # list emulators, simulators, and devices
simutil launch <device-id>    # boot a device
simutil plugin list           # YAML plugins from ~/.simutil/settings.yaml
simutil --help
```

Full documentation, plugin guide, and CLI reference:
<https://github.com/dungngminh/simutil>.
