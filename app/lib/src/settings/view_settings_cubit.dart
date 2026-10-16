import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';
import 'package:simutil_app/src/recording/grid_record_quality.dart';
import 'package:simutil_app/src/settings/desktop_settings_store.dart';

/// How open streams share the window.
enum StreamLayout {
  /// Equal tiles that fill the window.
  grid,

  /// One large stream with the others in a strip on the right.
  spotlightVertical,

  /// One large stream with the others in a row along the bottom.
  spotlightHorizontal,
}

/// Display and launch options.
final class ViewSettings extends Equatable {
  const ViewSettings({
    this.headless = true,
    this.layout = StreamLayout.grid,
    this.spotlightId,
    this.gridQuality = GridRecordQuality.standard,
  });

  /// Reads what [toJson] wrote; missing or invalid fields keep defaults.
  factory ViewSettings.fromJson(Object? json) {
    const defaults = ViewSettings();
    return ViewSettings(
      headless: readField<bool>(json, 'headless') ?? defaults.headless,
      layout:
          enumByName(StreamLayout.values, readField<String>(json, 'layout')) ??
          defaults.layout,
      spotlightId: readField<String>(json, 'spotlightId'),
      gridQuality:
          enumByName(
            GridRecordQuality.values,
            readField<String>(json, 'gridQuality'),
          ) ??
          defaults.gridQuality,
    );
  }

  /// Start emulators/simulators without their own window and stream them
  /// here once booted.
  final bool headless;

  final StreamLayout layout;

  /// Device shown large in the spotlight layouts; the first stream when
  /// null or no longer open.
  final String? spotlightId;

  /// Preset for the next grid recording.
  final GridRecordQuality gridQuality;

  ViewSettings copyWith({
    bool? headless,
    StreamLayout? layout,
    String? Function()? spotlightId,
    GridRecordQuality? gridQuality,
  }) => ViewSettings(
    headless: headless ?? this.headless,
    layout: layout ?? this.layout,
    spotlightId: spotlightId != null ? spotlightId() : this.spotlightId,
    gridQuality: gridQuality ?? this.gridQuality,
  );

  Map<String, Object?> toJson() => {
    'headless': headless,
    'layout': layout.name,
    'spotlightId': spotlightId,
    'gridQuality': gridQuality.name,
  };

  @override
  List<Object?> get props => [headless, layout, spotlightId, gridQuality];
}

/// View settings, restored from and saved to [store] when given.
class ViewSettingsCubit extends CubitSignal<ViewSettings> {
  ViewSettingsCubit({DesktopSettingsStore? store})
    : _store = store,
      super(initialState: ViewSettings.fromJson(store?.section(_key)));

  static const _key = 'view';
  final DesktopSettingsStore? _store;

  @override
  void onChange(Change<ViewSettings> change) {
    super.onChange(change);
    _store?.write(_key, change.nextState.toJson());
  }

  void toggleHeadless() =>
      emit(stateValue.copyWith(headless: !stateValue.headless));

  void setGridQuality(GridRecordQuality quality) =>
      emit(stateValue.copyWith(gridQuality: quality));

  void setLayout(StreamLayout layout) =>
      emit(stateValue.copyWith(layout: layout));

  /// Shows [deviceId] large, keeping the current spotlight orientation
  /// (vertical when coming from the grid).
  void spotlight(String deviceId) => emit(
    stateValue.copyWith(
      layout: stateValue.layout == StreamLayout.grid
          ? StreamLayout.spotlightVertical
          : stateValue.layout,
      spotlightId: () => deviceId,
    ),
  );
}
