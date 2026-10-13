# Changelog

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
