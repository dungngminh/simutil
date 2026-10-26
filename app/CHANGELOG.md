# Changelog

All notable changes to the SimUtil desktop app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Open a stream in its own window: the window button on a stream's header
  moves that device out of the grid into a separate, resizable window.
  Streaming the device again brings its window to the front; "Back to the
  main window" returns it to the grid, and closing the window ends the
  stream. Closing the main window while device windows are open only hides
  it (the Dock icon brings it back); SimUtil quits once the last device
  window closes.

### Changed

- A stream's title wraps to two lines before it is cut. Settings changed in a device window last until it
  closes.

## [0.5.0] - 2026-10-23

### Added

- Pick what an Android emulator's back and front cameras see: your Mac's
  webcam, an image or a video file. Set it from the device menu (Camera,
  used from the next start) or the camera button on a running emulator's
  stream (restarts it). SimUtil asks for Camera access before an emulator
  uses your webcam. Agents can set it over MCP too.
- Give iOS simulator apps a camera (macOS): pick your Mac's webcam, an
  image or a looping video from the device menu (Camera) or the camera
  button on its stream, then open an app with it; switching the source
  updates running apps live, and closing its stream or shutting it down
  turns the camera off. Agents can pass
  a camera to launch_app over MCP. Uses serve-sim's camera injector.

### Changed

- Connected iPhones and iPads show up faster, and their device frame loads
  without waiting on `devicectl`.
- Android emulators stream straight from the emulator on macOS, like
  Android Studio's embedded emulator: a steady 60 fps with less load on
  the emulator, sized to the view. Older emulators, ones started without
  gRPC, and other platforms keep using scrcpy. Emulator recordings are
  made by the emulator itself.

### Fixed

- Android emulators started for streaming (headless) use your computer's
  GPU: their stream runs at full speed instead of a few frames a second.
- Streaming an Android emulator right as it starts no longer fails with
  "scrcpy server did not start"; the stream waits for Android to finish
  booting.

## [0.4.0]

### Added

- Update SimUtil from inside the app: on launch a toast tells you when a
  newer version is out, and "Update & restart" installs it the way you
  installed SimUtil (Homebrew, DMG, Windows installer or AppImage), no
  reinstall needed, with download and install progress, and a toast once
  the new version starts. Missed it? Click the arrow next to the SimUtil
  title.
- The app remembers your settings between launches: stream layout,
  headless mode, grid recording quality, Slim mode, and each device's
  stream options (frame, scrcpy resolution, frame rate, bit rate, touches,
  stay awake, screen off).

### Changed

- Pump `simutil_apple` to 1.3.1 for supporting iOS real devices discovery in later macOS 27 and older than macOS 27

### Fixed

- Streaming an iPhone connected only over Wi-Fi no longer shows another
  iPhone's screen. Wi-Fi streaming is not supported yet; connect it by USB
  cable.
- Wiping or deleting a simulator / emulator shows a loading toast that turns
  into a success or error toast, instead of a red toast on success.

## [0.3.0] - 2026-10-14

### Added

- Install apps by dropping them on a device: drag an `.apk` onto an Android
  stream or device row, or an `.app` / `.ipa` onto an iOS one.
- `install_app` MCP tool installs an app file on a device.
- Dropping an iPhone build on a simulator offers to convert it so it runs
  there (Apple Silicon Macs, apps not downloaded from the App Store); the
  `install_app` MCP tool does the same with `convert_for_simulator`.
- Stream an iPhone or iPad connected by USB cable (view only, on macOS),
  with its device frame, screenshots and recording with sound.

### Changed

- Real devices are listed before emulators and simulators.
- Unplugging or disconnecting a streamed device closes its stream right
  away, saving a running recording.

### Fixed

- iPhones and iPads connected by cable no longer go missing from the device
  list until Xcode connects to them.

## [0.2.0] - 2026-10-13

### Added

- Screenshot button on each stream and for the whole grid; images are saved
  next to recordings.
- Type on a device from your keyboard: turn on the keyboard button of a
  stream and keys, including arrows, Enter and Backspace, go to it; using
  another device turns it off.
- Reorder the grid by dragging: long-press a stream's title bar and it
  follows the pointer while the other streams slide out of the way.
- More scrcpy options in an Android device's context menu (under "scrcpy
  options"): show touches, stay awake, turn the device screen off while
  streaming, screen off when the stream closes.
- Console Log panel: tap the logo five times to see MCP calls, running shell
  commands and app state changes as they happen.
- A stream that disconnects closes its tile (a running recording is saved
  first); a stream that fails to start still shows why.
- Wipe data for a shut-down emulator or simulator, right in its context
  menu next to Delete (no submenu any more).

### Fixed

- Top bar buttons respond right away instead of after a short delay.
- "scrcpy server did not start" now says why the server failed, and a slow
  emulator gets more time to start it.

## [0.1.0] - 2026-10-12

First version of the desktop app (macOS, Windows, Linux).

### Added

- Stream and control many Android emulators / devices and iOS simulators side
  by side, in a grid or spotlight layout, with touch, swipe and navigation
  buttons on every stream.
- The device list shows each device's iOS or Android version; its state
  shows as the dot on the icon.
- Start devices headless; launch an Android emulator with Cold Boot, No
  Audio or both from its context menu.
- Slim mode for iOS simulators: background services off, about 1 GB of memory
  each instead of 4 GB.
- Connect Android devices over Wi-Fi with a QR code, a pairing code or an IP.
- Record one device or the whole grid. On macOS grid recording is native,
  smooth and color-accurate, with a 60 fps "Smooth" preset.
- Recording time (`REC 00:01:23`) on the recording device and next to the
  grid's stop button.
- MCP server so agents can list, start, stream, tap, swipe, screenshot and
  record devices.
- MCP scenarios run on many devices at once, starting together. iOS
  simulators switch to Slim mode first, with a notice.
- MCP device list shows each stream's frames per second.
- Stop a running scenario from the studio's Stop button or the MCP
  `stop_scenario` tool.
- Scenario launches restart the app fresh; `clear_state: true` also wipes
  its data first.
- Taps by label press the element natively (Android `input tap` at its
  pixels, iOS simulators through accessibility), falling back to a touch.
- MCP can launch apps, type text and tap elements by their accessibility
  label, so one scenario works across screen sizes; scenario steps can
  repeat. A dot on the stream shows where an agent taps or swipes.
- With many streams the grid keeps tiles at a usable size and scrolls,
  instead of shrinking every stream to a sliver.
- Scenario studio beside the streams: write a scenario in YAML (or open a
  .yaml file), run it, and watch each step's status next to its line; a
  failed step shows its error. Scenarios agents run show there too.
- Scenario steps can run only when an element is (or is not) on screen
  (`if_visible`, `if_not_visible`; skipped steps show as skipped), and
  `assert_visible` / `assert_not_visible` check the screen.
- The scenario editor colors the YAML and suggests actions, options,
  buttons and device names as you type.
- MCP swipes can start on an element and repeat until another shows up, to
  scroll lists and pickers to a value.
- Installers: a DMG for macOS (also `brew install --cask`), a setup `.exe`
  for Windows (also `winget`), and an AppImage for Linux (also a one-line
  install script). Each also installs adb and FFmpeg.
- Android streaming works without installing scrcpy: the app brings its own
  scrcpy server.

### Changed

- Android streams recover within a second after dropping frames. On macOS
  they also decode off the UI thread, so many streams stay smooth while the
  app is busy.
- Shorter Slim mode texts in the toolbar, menus and toasts.

### Fixed

- iPhone Air shows its own device frame instead of a stretched Pro Max one.
