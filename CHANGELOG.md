# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Prevent device refresh from hanging forever when a simulator or device lookup stalls.

## [0.5.0] - 2026-05-02

### Changed

- Add Windows PowerShell installer command (`install.ps1`) to README installation section.

- Refactor Wi-Fi pairing flow to match Android Studio: discover pairing-code endpoints first, require code entry after selecting a discovered device, then resolve and connect to the post-pair ADB connect endpoint.

### Fixed

- Fix text color in dialogs and panels to avoid wrong overlay effect.

## [0.4.1] - 2026-04-11

### Fixed

- Fix incorrect way to terminate app.

## [0.4.0] - 2026-04-05

### Added

- Add Logcat dialog for launching Android emulators / devices.

## [0.3.2] - 2026-03-28

### Fixed

- Fixed iOS devices discovery when device is not connected.
- Fixed dialogs and panels color

## [0.3.1] - 2026-03-26

### Added

- Add macOS Intel support.

## [0.3.0] - 2026-03-23

### Added

- Add `shutdown` action for Android emulators and iOS simulators.

### Changed

- Change default keymap for `launch` and `launch with option` actions for Android emulators.

## [0.2.1] - 2026-03-21

### Fixed

- Fix wrong focus when initializing app.

## [0.2.0] - 2026-03-21

### Added

- Add iOS devices discovery.
- Add `SelectionArea` in Detail panel to allow user to select.

### Changed

- ADB tools can be accessed from any panel.
- Replace Android emulator id with serial id when device is launching.

## [0.1.0] - 2026-03-20

### Added

- Support Android physical devices

### Changed

- Reopen ADB tools menu

## [0.0.4] - 2026-03-17

### Changed

- Temporarily hide ADB Tools menu

### Fixed

- Fix build error

## [0.0.3] - 2026-03-17

### Changed

- Temporarily hide ADB Tools menu

## [0.0.2] - 2026-03-16

### Added

- Add version command

## [0.0.1]

### Added

- Add conditional UI for iOS (only available on macOS)

### Fixed

- Fix UI layout
- Fix idle message doesn't change when change panel

## [0.0.1] - 2026-03-15

### Added

- Initial release
