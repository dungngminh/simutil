/// UI-agnostic SimUtil app layer shared by the TUI and the GUI.
///
/// Settings (`~/.simutil/settings.yaml`), app state (`~/.simutil/state.json`),
/// bundled changelog entries, refresh intervals, and [ServiceLocator] wiring.
/// Must not depend on `nocterm` or Flutter.
library;

export 'src/app_settings.dart';
export 'src/app_state.dart';
export 'src/changelog_entries.dart';
export 'src/constants.dart';
export 'src/service_locator.dart';
export 'src/settings_service.dart';
export 'src/update_checker.dart';
