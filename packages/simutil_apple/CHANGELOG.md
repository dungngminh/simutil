# Changelog

## 1.4.1

- `IOSDeviceService` gives its `simctl list`, `devicectl list`,
  `xcode-select` and `open` calls a 30 s timeout, and `simctl shutdown` /
  `delete` / `erase` 2 min. A stuck CoreSimulatorService or CoreDevice
  froze the device list: every refresh joined the same never-ending
  background command.
- The `devicectl` fallback writes its JSON into a temp directory of its
  own; a fixed `$TMPDIR/ios_devices.json` let the TUI, the app and the CLI
  read or delete each other's output.
- `listUsbmuxDevices` / `lockdownValues` close the usbmuxd socket when a
  request times out; it stayed open until usbmuxd answered. Their
  `timeout` now bounds the whole call instead of each connection and
  exchange.
- `SimulatorRecorder.start` completes once `simctl` reports
  `Recording started` and throws a `StateError` with its error (e.g.
  `Cannot create file`); `stop` returns null when the recording failed or
  was not finalized instead of the path of a missing or broken file. A
  second `start` joins one in progress instead of launching another
  `simctl`, and `stop` during `start` stops what the start launched.

## 1.4.0

- `IOSDeviceService.getPhysicalDevices` asks usbmuxd (`ListDevices`) and
  each device's lockdownd (`GetValue`, no pairing session) instead of
  running `devicectl`; it falls back to `devicectl list devices` only when
  usbmuxd or a device does not answer. Device ids are now hardware UDIDs on
  both paths (`hardwareProperties.udid` from `devicectl`), not CoreDevice
  identifiers. New optional `listUsbmuxDevices` constructor parameter for
  tests.
- `lockdownValues(udid)` reads a connected device's lockdownd values
  (`DeviceName`, `ProductType`, `ProductVersion`, ...).
- `IosAutomation.launchWithCamera` grants a simulator app camera access and
  relaunches it with a camera injector dylib inserted
  (`SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`) and its shared memory name
  (`SIMCTL_CHILD_SIMCAM_SHM_NAME`), for the SimUtil desktop app's simulator
  camera.
- `IosAutomation.installedApps` lists a simulator's user-installed apps
  (`simctl listapps`).

## 1.3.1

- `IOSDeviceService.getPhysicalDevices` passes
  `--filter "Reality = 'physical'"` to `devicectl` only on Xcode 27+
  (DeviceHub.app present), where booted simulators are listed too. On older
  Xcode that filter matches nothing and hid every connected iPhone / iPad.
- New `IOSDeviceService.listPhysicalDevicesArguments` and
  `IOSDeviceService.isDeviceHub`.

## 1.3.0

- `IosAutomation.install` installs an `.app` or `.ipa` (unpacked first)
  with `simctl install` on simulators and `devicectl device install app` on
  devices; a device-only build on a simulator, or an App Store-signed build
  on a device, fails early with a clear message. Requires `simutil_core` 1.3.0.
- `convertForSimulator(exec, app)` makes a device-built, unencrypted arm64
  app run on an Apple Silicon simulator: `lipo` / `vtool` re-tag every
  Mach-O as iOS Simulator and `codesign -s -` re-signs it.
  `IosAutomation.installForSimulator` converts a copy and installs it;
  `install` throws `DeviceOnlyBuildException` for a device-only build.
- `IOSDeviceService.getPhysicalDevices` lists a device connected by cable
  or Wi-Fi even while its CoreDevice tunnel is closed.

## 1.2.0

- `IOSDeviceService.wipeData` erases a simulator (`simctl erase`).
  Requires `simutil_core` 1.2.0.

## 1.1.0

- `launchDevice(headless: true)` boots without opening the Simulator app.
- `deleteSimulator` runs `simctl delete`.
- `watchDevices()` follows CoreSimulator's device set through FSEvents
  (`device.plist` writes on boot / shutdown, devices added or removed) and
  usbmuxd `Listen` attach / detach events for physical devices, instead of
  polling.
- Device listing (`simctl list`, `devicectl list`) runs at
  `CommandPriority.background`; boot, open, shutdown and delete at
  `interactive`.
- `SimulatorSlimmer`: disables simulator background daemons by category
  (`slimCategories`, ported from simslim) to cut memory per simulator.
- `SimulatorRecorder`: records a simulator screen with
  `simctl io recordVideo`.
- `IosAutomation`: relaunches apps with `simctl launch
  --terminate-running-process` (simulators; `clearState` empties the data
  container first) or `devicectl device process launch --terminate-existing`
  (devices); typing and accessibility
  need a native bridge and throw `UnsupportedError`; `tapElement` returns
  false.

## 1.0.0

- Initial release, extracted from the `simutil` app.
