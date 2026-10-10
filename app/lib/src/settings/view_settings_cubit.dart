import 'package:bloc_signals/bloc_signals.dart';
import 'package:equatable/equatable.dart';

/// Display and launch options.
final class ViewSettings extends Equatable {
  const ViewSettings({this.showFrames = true, this.headless = true});

  /// Draw a device bezel around each stream.
  final bool showFrames;

  /// Start emulators/simulators without their own window and stream them
  /// here once booted.
  final bool headless;

  ViewSettings copyWith({bool? showFrames, bool? headless}) => ViewSettings(
    showFrames: showFrames ?? this.showFrames,
    headless: headless ?? this.headless,
  );

  @override
  List<Object?> get props => [showFrames, headless];
}

class ViewSettingsCubit extends CubitSignal<ViewSettings> {
  ViewSettingsCubit() : super(initialState: const ViewSettings());

  void toggleFrames() =>
      emit(stateValue.copyWith(showFrames: !stateValue.showFrames));

  void toggleHeadless() =>
      emit(stateValue.copyWith(headless: !stateValue.headless));
}
