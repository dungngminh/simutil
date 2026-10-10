# Changelog

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

## 1.0.0

- Initial release, extracted from the `simutil` app.
