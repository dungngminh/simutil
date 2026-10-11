# Changelog

All notable changes to the SimUtil desktop app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

First version of the desktop app (macOS, Windows, Linux).

### Added

- Stream and control many Android emulators / devices and iOS simulators side
  by side, in a grid or spotlight layout, with touch, swipe and navigation
  buttons on every stream.
- Start devices headless.
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
- MCP can launch apps, type text and tap elements by their accessibility
  label, so one scenario works across screen sizes; scenario steps can
  repeat. A dot on the stream shows where an agent taps or swipes.
- Scenarios panel lists each scenario step by step: a spinner on the step
  running, a check on steps done, the error on the step that failed.
- MCP swipes can start on an element and repeat until another shows up, to
  scroll lists and pickers to a value.
- Write a scenario in YAML (or open a .yaml file) and run it on your
  devices from the scenarios panel, without an agent.

### Changed

- Android streams recover within a second after dropping frames. On macOS
  they also decode off the UI thread, so many streams stay smooth while the
  app is busy.
- Shorter Slim mode texts in the toolbar, menus and toasts.
