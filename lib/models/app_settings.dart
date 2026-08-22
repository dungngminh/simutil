/// User preferences persisted in settings.yaml.
class AppSettings {
  /// Creates settings with optional [themeName] and [lastSelectedDeviceId].
  const AppSettings({
    this.themeName = 'dark',
    this.lastSelectedDeviceId,
  });

  /// Parses settings from a JSON map.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeName: json['themeName'] as String? ?? 'dark',
      lastSelectedDeviceId: json['lastSelectedDeviceId'] as String?,
    );
  }

  /// Theme name (e.g. `dark`).
  final String themeName;

  /// Last selected device id, if any.
  final String? lastSelectedDeviceId;

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    String? themeName,
    String? lastSelectedDeviceId,
  }) {
    return AppSettings(
      themeName: themeName ?? this.themeName,
      lastSelectedDeviceId: lastSelectedDeviceId ?? this.lastSelectedDeviceId,
    );
  }

  /// Serializes settings to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'themeName': themeName,
      'lastSelectedDeviceId': lastSelectedDeviceId,
    };
  }
}
