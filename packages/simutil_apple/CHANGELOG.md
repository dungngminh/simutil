# Changelog

## 1.1.0

- `launchDevice(headless: true)` boots without opening the Simulator app.
- `SimulatorSlimmer`: disables simulator background daemons by category
  (`slimCategories`, ported from simslim) to cut memory per simulator.
- `SimulatorRecorder`: records a simulator screen with
  `simctl io recordVideo`.

## 1.0.0

- Initial release, extracted from the `simutil` app.
