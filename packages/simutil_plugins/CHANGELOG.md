# Changelog

## Unreleased

- `PluginRunner.run` waits for `mode: inherit` commands to exit and reports
  the result; `PluginRunResult` gains `exitCode` (`null` for detached).

## 1.0.0

- Initial release, extracted from the `simutil` app.
