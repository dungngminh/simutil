import 'package:simutil/models/launch_options.dart';

class AppSettings {

  const AppSettings({
    this.themeName = 'dracula',
    this.defaultLaunchOptions = const LaunchOptions(),
    this.lastSelectedDeviceId,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeName: json['themeName'] as String? ?? 'dark',
      defaultLaunchOptions: json['defaultLaunchOptions'] != null
          ? LaunchOptions.fromJson(
              json['defaultLaunchOptions'] as Map<String, dynamic>)
          : const LaunchOptions(),
      lastSelectedDeviceId: json['lastSelectedDeviceId'] as String?,
    );
  }
  final String themeName;

  final LaunchOptions defaultLaunchOptions;

  final String? lastSelectedDeviceId;

  AppSettings copyWith({
    String? themeName,
    LaunchOptions? defaultLaunchOptions,
    String? lastSelectedDeviceId,
  }) {
    return AppSettings(
      themeName: themeName ?? this.themeName,
      defaultLaunchOptions: defaultLaunchOptions ?? this.defaultLaunchOptions,
      lastSelectedDeviceId: lastSelectedDeviceId ?? this.lastSelectedDeviceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeName': themeName,
      'defaultLaunchOptions': defaultLaunchOptions.toJson(),
      'lastSelectedDeviceId': lastSelectedDeviceId,
    };
  }
}
