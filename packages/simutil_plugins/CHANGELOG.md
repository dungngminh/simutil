# Changelog

## 1.0.0

- Initial release, extracted from the `simutil` app.
- `PluginRunner.run` waits for `mode: inherit` commands to exit and reports
  the result; `PluginRunResult.exitCode` is `null` for detached commands.
