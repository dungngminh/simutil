# AGENTS.md

## What this is

`simutil` is a cross-platform Dart TUI + CLI for launching Android emulators
and iOS simulators, with built-in ADB tools (IP / pair-code / QR connect) and
Logcat viewer. A Flutter desktop GUI (`apps/simutil_app`) is planned. Entry
point: [packages/simutil/bin/simutil.dart](packages/simutil/bin/simutil.dart) — no args → `runSimutilTui()`,
otherwise `runSimutilCli(args)`. Main TUI component:
[packages/simutil/lib/src/tui/app/simutil_tui_app.dart](packages/simutil/lib/src/tui/app/simutil_tui_app.dart).
User-facing docs: [README.md](README.md).

## Stack (only the non-obvious bits)

- Dart `^3.11.0`. UI framework is `[nocterm](https://nocterm.dev/)` — a Flutter-like
  component model for terminals (`StatefulComponent`, `BuildContext`, `Focusable`,
  `setState`). Treat widgets as Flutter widgets.
- CLI uses `args` `CommandRunner` — see [packages/simutil/lib/src/cli](packages/simutil/lib/src/cli/).
  `packages/simutil/bin/simutil.dart` delegates to `SimutilCommandRunner` when args are present.
- All external shell commands in **services** go through `CommandExec` →
  `IsolateRunner` (see [packages/simutil_core](packages/simutil_core/)
  and [packages/simutil_shared/lib/src/service_locator.dart](packages/simutil_shared/lib/src/service_locator.dart)).
  Do not call `Process.run` or `Process.start` directly inside workspace
  services. See **CommandExec** below for when exceptions apply.

## CommandExec

Shell work must not block the Nocterm UI isolate. `ServiceLocator` wires
`CommandExec.isolate(isolateRunner)` and passes it into services that spawn
subprocesses (e.g. `AndroidDeviceService`, `IOSDeviceService`, `SettingsService`,
`PluginRunner` for availability probes).

**Use `CommandExec.run`** when the service needs a one-shot command and may wait
for exit + stdout/stderr (adb, emulator, xcrun, `open` / `xdg-open`, `--version`
probes). Inject `CommandExec` via constructor; resolve the exec from
`ServiceLocator.instance.commandExec` only when wiring in the locator — not in
widgets or ad-hoc service construction.

```dart
class MyService {
  MyService(this._exec);
  final CommandExec _exec;

  Future<bool> probe() async {
    final result = await _exec.run('tool', arguments: ['--version']);
    return result.success;
  }
}
```

**Do not use `CommandExec`** when the process must outlive the call or share
stdio with the user:

- Plugin **launch** (GUI / long-running): `Process.start` with
  `ProcessStartMode.detached` or `inheritStdio` in
  [packages/simutil_plugins/lib/src/plugin_runner.dart](packages/simutil_plugins/lib/src/plugin_runner.dart).
- Logcat streaming: `Process.start` in plugin code under `packages/simutil/lib/src/tui/dialogs/`.

**Testing:** import `package:simutil_core/testing.dart` (`FakeCommandExec`, `FakeDeviceService`, device fixtures) or `package:simutil_plugins/testing.dart` (`FakePluginRunner`) instead
of spawning real processes. Never call `Process.run` inside service unit tests
when the production path goes through `CommandExec`.

**Docs:** full data-flow diagram and invariants in
[docs/ai/architecture.md](docs/ai/architecture.md); plugin launch exception in
[docs/ai/plugins.md](docs/ai/plugins.md).

## Layout

Monorepo; the root `pubspec.yaml` (`name: _`, `publish_to: none`) only lists the
workspace and Melos scripts. All Dart code lives in `packages/`.
See [docs/ai/architecture.md](docs/ai/architecture.md).

| Package | Contents |
| --- | --- |
| `packages/simutil_core` | models, `DeviceService`, `CommandExec`, `IsolateRunner` |
| `packages/simutil_adb` / `simutil_apple` | device services (adb, simctl/devicectl), `LogcatHelper` |
| `packages/simutil_plugins` | `PluginCatalog`, `PluginRunner` |
| `packages/simutil_shared` | UI-agnostic app layer: settings, app state, changelog entries, `ServiceLocator` |
| `packages/simutil` | the app (published as `simutil`): `bin/simutil.dart`, `lib/src/cli/` (`runSimutilCli`, `SimutilCommandRunner`), `lib/src/tui/` (nocterm: `app`, `components`, `dialogs`, `terminal`), `tool/` codegen, app `CHANGELOG.md` |

Dependency rules: `simutil_shared` never imports `nocterm` or Flutter; no
library imports `package:simutil/` (the app). Tests live in each `packages/*/test/`;
`packages/simutil/test/tool/` covers the codegen tools.

## Build / run / verify

Monorepo uses [Melos](https://melos.invertase.dev/) on top of Dart pub
workspaces. After `dart pub get`, use `dart run melos …` (Melos is a root
dev dependency).

```bash
dart pub get
dart run melos bootstrap          # pub get for the workspace (alias: dart pub get)
dart run melos run cli             # TUI locally (CLI args after --)
dart run melos run analyze        # analyze all packages
dart run melos run test           # test all packages
dart run melos run check          # analyze + test (CI parity)
dart run melos run codegen        # regenerate changelog_entries.dart + version.dart
dart run melos run compile        # compile ./simutil binary
dart --enable-vm-service packages/simutil/bin/simutil.dart  # hot reload (direct)
dart run packages/simutil/bin/simutil.dart         # run without melos
```

[version.dart](packages/simutil/lib/src/version.dart) and
[changelog_entries.dart](packages/simutil_shared/lib/src/changelog_entries.dart)
are generated by `packages/simutil/tool/generate_version.dart` (`packages/simutil/pubspec.yaml` version) and
`packages/simutil/tool/generate_changelog.dart` (`CHANGELOG.md`) — do not hand-edit. CI definition lives in
[.github/workflows/ci.yaml](.github/workflows/ci.yaml).

## Gotchas

- iOS code paths must be guarded by `Platform.isMacOS` — see
  [packages/simutil_apple/lib/src/ios_device_service.dart](packages/simutil_apple/lib/src/ios_device_service.dart)
  and the `_iosSimulatorsPanel` guard in [packages/simutil/lib/src/tui/app/simutil_tui_app.dart](packages/simutil/lib/src/tui/app/simutil_tui_app.dart).
- TUI code resolves services from `ServiceLocator.instance`; do not instantiate
  them ad-hoc. The CLI (`lib/src/cli/`) builds its own via `CliDeviceServices`
  with `CommandExec()` (no isolate) and takes fakes through constructors.
- Services with I/O are `abstract interface class Foo` with
  `factory Foo(...) = _ImplName;` and a private implementation (like `dart:io`
  `File`). No public `FooImpl` classes; parsed data is an immutable value
  (e.g. `PluginCatalog`), not a stateful service.
- Android tooling resolves via `ANDROID_HOME` / `ANDROID_SDK_ROOT`, falling back
  to `~/Library/Android/sdk` — see [packages/simutil_adb/lib/src/android_device_service.dart](packages/simutil_adb/lib/src/android_device_service.dart).
- Code style is enforced by [analysis_options.yaml](analysis_options.yaml). Rely on
  `dart analyze` / `dart format` rather than restating rules here.

## When changing code

- Log mainly user-visible changes in the package's `CHANGELOG.md` (app:
  [packages/simutil/CHANGELOG.md](packages/simutil/CHANGELOG.md)) using Keep-a-Changelog
  sections (`Added` / `Changed` / `Fixed`). **Check whether the newest
  version heading is released first**: released = has a git tag
  (`git tag -l 'v*'` for `simutil`, `git tag -l 'simutil_<pkg>-v*'` for a
  library) **or** is on pub.dev (`curl -s https://pub.dev/api/packages/<pkg>`,
  `latest.version`; libraries 1.0.0 were published without tags).
  - Not released: add the entry under that version and describe the final
    state (no "X replaced Y" between unreleased drafts).
  - Released, app: add under `[Unreleased]`.
  - Released, library: bump `version:` in its `pubspec.yaml` (patch for fixes,
    e.g. 1.0.0 → 1.0.1; minor for new API) and add the entry under a new
    `## X.Y.Z` heading.
  After editing the app changelog, run `dart run melos run codegen`.
  The app changelog is shown to users in the TUI "what's new" dialog: keep
  bullets short and in plain language (what the user sees or can do), no
  internal class / file names. Library changelogs (`simutil_<pkg>`) target
  Dart developers and may name APIs.
- Follow [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) — fill
  the description and tick the Type-of-Change checkboxes.
- For UI/dialog code, always split large widget trees into smaller focused components
  (prefer reusable `StatelessComponent`/`StatefulComponent` units over monolithic build methods).
- Before finishing: `dart analyze --fatal-infos` must pass.
- More: [docs/ai/contributing.md](docs/ai/contributing.md),
  [docs/ai/deployment.md](docs/ai/deployment.md) (release pipeline),
  [docs/ai/plugins.md](docs/ai/plugins.md) (YAML plugin system internals).
