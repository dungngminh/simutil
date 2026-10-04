# Changelog

## 1.0.0

- Initial release, extracted from the `simutil` app.
- `CommandExec()` runs commands in-process; `CommandExec.isolate(runner)`
  runs them on an `IsolateRunner` background isolate.
- `CommandExec()` kills the process when `timeout` elapses.
- `CommandExec()` and `IsolateRunner` close the child's stdin, so commands
  that read stdin see EOF instead of hanging.
