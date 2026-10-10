# SimUtil desktop

Flutter desktop app (macOS, Windows, Linux): a tray menu that lists and
starts devices, and a window that streams and controls many Android
emulators/devices and iOS simulators side by side.

- Start devices headless (no emulator window / Simulator app) and stream
  them into the grid; stop them; slim iOS simulators to save memory.
- Touch, swipe and navigation buttons on every stream; Apple device frames
  for simulators (from your Xcode), drawn frames otherwise.
- Record one device or the whole grid to `~/Movies/SimUtil`
  (`~/Videos/SimUtil` on Windows/Linux).
- Right-click a device for per-device settings (headless, cold boot,
  stream resolution / frame rate / bit rate).
- MCP server for agents at `http://127.0.0.1:8765/mcp`
  (`SIMUTIL_MCP_PORT`); the tray menu copies the URL.

## Requirements

- Android streaming: [scrcpy](https://github.com/Genymobile/scrcpy) 3+ installed
  (`brew install scrcpy`, `scoop install scrcpy`, `apt install scrcpy`) or
  `SCRCPY_SERVER_PATH` pointing at its `scrcpy-server`.
- iOS streaming: macOS with Xcode. On Xcode 27, Device Hub may take over input;
  the tile offers a repair (restarts the simulator's apps).
- Recording: `ffmpeg` (grid recording, and `.mp4` output for Android).
- Linux build: `libgtk-3-dev libx11-dev libxi-dev libmpv-dev`.

## Run

```bash
flutter pub get
flutter run -d macos   # or windows / linux
```
