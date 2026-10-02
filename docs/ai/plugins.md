# Plugin system (internals)

How the YAML plugin feature is wired internally. Progressive disclosure from
[architecture.md](architecture.md). For the user-facing schema and examples see
[docs/plugins.md](../plugins.md); keep that doc in sync when changing behaviour.

## What it is

Users register external **shell-command tools** in the `plugins:` section of
`~/.simutil/settings.yaml`. SimUtil parses them at startup, filters by the selected
device, and runs them via `Process.start`. No Dart code changes are needed to add
a tool. Plugins cannot add custom TUI screens — they are command launchers only.

## Moving parts

| File | Role |
| --- | --- |
| [packages/simutil_plugins/lib/src/models/plugin_config.dart](../../packages/simutil_plugins/lib/src/models/plugin_config.dart) | Data + parsing. `PluginConfig`, `PluginCommandConfig`, `PluginRunMode`, `PluginAvailabilityCheck`, `PluginCommandRef`. Pure Dart, no I/O. |
| [packages/simutil_plugins/lib/src/settings_file.dart](../../packages/simutil_plugins/lib/src/settings_file.dart) | Config path (`defaultSettingsPath`), default `plugins:` template, `ensurePluginsSection` (appends the section only when the key is missing). |
| [packages/simutil_plugins/lib/src/plugin_catalog.dart](../../packages/simutil_plugins/lib/src/plugin_catalog.dart) | `PluginCatalog`: immutable parse result with `warnings`; `forDevice`, shortcut lookups, `plugin` / `command` by id. `loadPluginCatalog()` is the only file I/O. |
| [packages/simutil_shared/lib/src/settings_service.dart](../../packages/simutil_shared/lib/src/settings_service.dart) | Owns `theme` / `last_selected_device_id`: inserts missing keys, `mergeSettingsScalars` on save; `openInEditor()` opens config via OS default app. |
| [packages/simutil_plugins/lib/src/plugin_runner.dart](../../packages/simutil_plugins/lib/src/plugin_runner.dart) | `PluginRunner` interface; `PluginRunner(exec)` factory returns the private process-backed runner (availability probe + launch). |
| [packages/simutil/lib/src/tui/dialogs/registry/](../../packages/simutil/lib/src/tui/dialogs/registry/) | TUI: `plugin_menu_dialog.dart`, `command_menu_dialog.dart`, shared `menu_option_row.dart`. |
| [packages/simutil_shared/lib/src/service_locator.dart](../../packages/simutil_shared/lib/src/service_locator.dart) | Wires `pluginCatalogLoader` + `pluginRunner`. |
| [packages/simutil/lib/src/tui/app/simutil_tui_app.dart](../../packages/simutil/lib/src/tui/app/simutil_tui_app.dart) | Loads the registry on init; handles `p`, dynamic shortcuts, and the two-step flow. |

## Model shape

```
PluginConfig
  id, label, description?, enabled, availability?, shortcut?
  commands: List<PluginCommandConfig>          // non-empty (validated)

PluginCommandConfig
  id, label, command, description?, args[],
  platforms: List<DeviceOs>, requiresRunning, mode, shortcut?, availability?
```

Key methods on the model (no I/O, easy to unit test):

- `PluginCommandConfig.matches(Device?)` — platform + running-state filter.
- `PluginCommandConfig.resolveArgs(Device?)` — interpolates `{device.*}`.
- `PluginConfig.commandsFor(Device?)` / `hasCommandsFor(Device?)`.
- `PluginCommandRef` — pairs a plugin with one of its commands (shortcut /
  selection result).

Parsing throws `FormatException` on invalid entries; required-field and
platform validation lives in the `fromMap` factories.

## Load + flow

```mermaid
flowchart TD
    Init["SimutilTuiApp._initApp"] --> Load["loadPluginCatalog()"]
    Load --> Ensure["ensurePluginsSection(settings.yaml)"]
    Ensure -->|no plugins: key| Write["append default plugins section"]
    Load --> Cache["_plugins = PluginCatalog"]

    P["press p"] --> ForDevice["_plugins.forDevice(selected)"]
    ForDevice --> PMenu["showPluginMenuDialog"]
    PMenu --> CMenu["showCommandMenuDialog"]
    CMenu --> RunCmd["_runPluginCommand"]
    RunCmd --> Avail["pluginRunner.isAvailable"]
    Avail -->|ok| Start["pluginRunner.run -> Process.start"]
    Avail -->|missing| Status["status: not found"]

    Sc["press a char key"] --> ShortLookup["_handlePluginShortcut"]
    ShortLookup -->|command shortcut| RunCmd
    ShortLookup -->|plugin shortcut| CMenu
```

Entry points in [packages/simutil/lib/src/tui/app/simutil_tui_app.dart](../../packages/simutil/lib/src/tui/app/simutil_tui_app.dart):

- `_initApp` stores `await _di.pluginCatalogLoader()` in `_plugins` before the
  first refresh, then shows the first catalog warning (if any) in the status bar.
- `_handleGlobalKey`: `LogicalKey.keyP` opens `_showPluginMenu`;
  `LogicalKey.keyE` opens `_openSettingsFile` (OS default editor); the `default`
  case forwards single, unmodified character keys to `_handlePluginShortcut`.
- `_showPluginMenu` → `_openCommandMenuForPlugin` → `_runPluginCommand`.

## Behavioural rules (must stay in sync with docs/plugins.md)

- **Availability order:** `command.availability` → `plugin.availability` →
  fallback `<command> --version`. Pass = exit code `0`.
- **Filtering:** a command shows when (`platforms` empty or contains device OS)
  **and** (`requiresRunning` false or device running). A plugin shows when it has
  ≥1 such command. `null` device fails any platform/running constraint.
- **Shortcuts:** normalized to lowercase single keys. Command-level runs
  directly; plugin-level opens that plugin's command menu. Built-in global keys
  (`p`, `e`, `r`, `n`, `l`, `t`, `q`, Tab/arrows/space/enter/esc) are matched before
  the shortcut fallback, so they win.
- **Defaults:** `enabled` true (only `enabled: false` hides), `mode` detached,
  `platforms` empty (any), `requiresRunning` false.
- **Resilience:** duplicate plugin ids are dropped (first wins); invalid entries
  are skipped with a `log(..., name: 'plugins')` warning; a malformed document
  yields an empty list. The app must still start.
- **Templates:** `{device.id|name|platform|os|state}`. `os` uses the enum name
  (`android`/`ios`); `state` uses the label (`Booted`/`Booting`/`Shutdown`).

## Intentional deviation from the CommandExec invariant

[architecture.md](architecture.md) states services never call `Process.run`
directly. Plugin availability probes go through `CommandExec` like other
services. Only plugin **launch** is the deliberate exception:

- Launch uses `Process.start` with `ProcessStartMode.detached` (GUI tools, fire
  and forget) or `inheritStdio` (blocking CLIs).

These are fire-and-forget launches, not captured shell output, so routing them
through `IsolateCommandExec` would add no value. Keep device discovery/launch in
the device services on `CommandExec`; only user plugin launches bypass it.

## Testing

- [packages/simutil_plugins/test/models/plugin_config_test.dart](../../packages/simutil_plugins/test/models/plugin_config_test.dart)
  — parse/validate, `matches`, `resolveArgs`, `commandsFor`.
- [packages/simutil_plugins/test/settings_file_test.dart](../../packages/simutil_plugins/test/settings_file_test.dart)
- [test/services/settings_service_test.dart](../../test/services/settings_service_test.dart)
  — default create, `mergeSettingsScalars`.
- [packages/simutil_plugins/test/plugin_catalog_test.dart](../../packages/simutil_plugins/test/plugin_catalog_test.dart)
  — `PluginCatalog.parse` on inline YAML: skip/dedupe with warnings, disabled,
  filtering, shortcuts, id lookup, malformed input. One test covers
  `loadPluginCatalog(path: ...)` seeding a temp file.
- [packages/simutil/test/cli/plugin_command_test.dart](../../packages/simutil/test/cli/plugin_command_test.dart)
  — injects `loadCatalog: () async => catalog` and a `_FakeRunner implements PluginRunner`.

## Extending — common changes

- **New command field:** add it to `PluginCommandConfig` + `fromMap`, document it
  in [docs/plugins.md](../plugins.md), add a parse test.
- **New template variable:** extend `_interpolate` in
  [plugin_config.dart](../../packages/simutil_plugins/lib/src/models/plugin_config.dart) and the variables
  table in [docs/plugins.md](../plugins.md).
- **New run mode:** extend `PluginRunMode` + the `switch` in
  `_ProcessPluginRunner.run` in `plugin_runner.dart`.
- **Reload at runtime:** call `_loadPlugins()` again from a key handler; the
  catalog is immutable, so reload is just a new value (currently startup-only).

## Gotchas

- The default YAML template is `defaultPluginsYaml` in
  [settings_file.dart](../../packages/simutil_plugins/lib/src/settings_file.dart);
  update it when the schema changes so first-run users get a valid sample.
- `omit_local_variable_types`, `prefer_single_quotes`, `require_trailing_commas`
  and `sort_constructors_first` are enforced — mirror the existing model layout
  (constructors first, then fields, then methods).
- Plugin UI dialogs follow the [adb_tools_dialog.dart](../../packages/simutil/lib/src/tui/dialogs/adb_tools/adb_tools_dialog.dart)
  pattern (overlay + `Focusable` + ↑/↓/enter/esc). Split large trees into small
  components per [AGENTS.md](../../AGENTS.md).
