/// Options for launching a simulator/emulator.
class LaunchOptions {
  /// Launch without audio (Android: `-no-audio`).
  final bool noAudio;

  /// Wipe user data before launch (Android: `-wipe-data`).
  final bool wipeData;

  /// GPU acceleration mode (Android: `-gpu <mode>`).
  /// Values: 'auto', 'host', 'swiftshader_indirect', 'off'.
  final String gpu;

  /// Don't load snapshot on boot (Android: `-no-snapshot-load`).
  final bool noSnapshot;

  const LaunchOptions({
    this.noAudio = false,
    this.wipeData = false,
    this.gpu = 'auto',
    this.noSnapshot = false,
  });

  LaunchOptions copyWith({
    bool? noAudio,
    bool? wipeData,
    String? gpu,
    bool? noSnapshot,
  }) {
    return LaunchOptions(
      noAudio: noAudio ?? this.noAudio,
      wipeData: wipeData ?? this.wipeData,
      gpu: gpu ?? this.gpu,
      noSnapshot: noSnapshot ?? this.noSnapshot,
    );
  }

  /// Convert launch options to emulator CLI arguments.
  List<String> toAndroidArgs() {
    final args = <String>[];
    if (noAudio) args.add('-no-audio');
    if (wipeData) args.add('-wipe-data');
    if (gpu != 'auto') args.addAll(['-gpu', gpu]);
    if (noSnapshot) args.add('-no-snapshot-load');
    return args;
  }

  factory LaunchOptions.fromJson(Map<String, dynamic> json) {
    return LaunchOptions(
      noAudio: json['noAudio'] as bool? ?? false,
      wipeData: json['wipeData'] as bool? ?? false,
      gpu: json['gpu'] as String? ?? 'auto',
      noSnapshot: json['noSnapshot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noAudio': noAudio,
      'wipeData': wipeData,
      'gpu': gpu,
      'noSnapshot': noSnapshot,
    };
  }
}
