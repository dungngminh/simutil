# Changelog

## 1.1.0

- `DeviceSession` interface for live device screens: `SessionStatus`
  (`SessionConnecting` / `SessionLive` / `SessionFailed`), `TouchPhase`,
  `DeviceButton` (back, home, recents, lock, volume up / down), input
  repair and screen recording.
- `DeviceService.launchDevice` takes `headless` to start without a window.
- `DeviceService.deleteSimulator` deletes a shut-down simulator/emulator;
  `FakeDeviceService` records it in `deleted`.
- `CommandQueue` and `CommandPriority`: `IsolateRunner` now schedules
  processes with bounded concurrency (`maxConcurrent`, default processor
  count clamped to 2..6), runs `interactive` work before `normal` and
  `background`, always keeps one slot free from background work, promotes
  background work waiting over 2 s, and shares one result between identical
  queued/running `background` commands.
- `CommandExec.run` takes `priority`; `FakeCommandCall` records it.
- `DeviceService.watchDevices()` signals device changes so callers reload
  instead of polling; `FakeDeviceService.emitDeviceChange()` drives it in
  tests.
- `mergeStreams` merges change streams; `reconnecting` keeps a long-lived
  watcher alive with exponential backoff.

## 1.0.0

- Initial release, extracted from the `simutil` app.
- `CommandExec()` runs commands in-process; `CommandExec.isolate(runner)`
  runs them on an `IsolateRunner` background isolate.
- `CommandExec()` kills the process when `timeout` elapses.
- `CommandExec()` and `IsolateRunner` close the child's stdin, so commands
  that read stdin see EOF instead of hanging.
