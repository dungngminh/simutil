import 'launch_options.dart';

/// Application-wide settings persisted to disk.
class AppSettings {
  /// Name of the nocterm theme to use.
  /// Options: 'dark', 'light', 'nord', 'dracula', 'catppuccin', 'gruvbox'.
  final String themeName;

  /// Default launch options applied when starting a device.
  final LaunchOptions defaultLaunchOptions;

  /// The ID of the last selected device (restored on startup).
  final String? lastSelectedDeviceId;

  const AppSettings({
    this.themeName = 'dark',
    this.defaultLaunchOptions = const LaunchOptions(),
    this.lastSelectedDeviceId,
  });

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

  Map<String, dynamic> toJson() {
    return {
      'themeName': themeName,
      'defaultLaunchOptions': defaultLaunchOptions.toJson(),
      'lastSelectedDeviceId': lastSelectedDeviceId,
    };
  }
}
