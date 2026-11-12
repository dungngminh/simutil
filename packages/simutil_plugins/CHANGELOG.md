# Changelog

## 1.0.1

- Without an explicit `availability` check, `PluginRunner.isAvailable`
  looks the command up on `PATH` (`which` / `where`) instead of running
  `<command> --version`, which started GUI tools and failed for tools such
  as `open` that reject the flag. A command given as a path must be an
  executable regular file (checked asynchronously). Availability probes
  time out after 10 s.

## 1.0.0

- Initial release, extracted from the `simutil` app.
- `PluginRunner.run` waits for `mode: inherit` commands to exit and reports
  the result; `PluginRunResult.exitCode` is `null` for detached commands.
