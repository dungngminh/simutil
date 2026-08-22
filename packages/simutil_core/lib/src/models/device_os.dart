/// OS family used to filter devices and plugins.
enum DeviceOs {
  /// Android emulators and hardware.
  android,

  /// Apple platforms (iPhone, iPad, Watch, TV, vision, Mac).
  ios;

  /// Short UI label (`Android` / `iOS`).
  String get label {
    switch (this) {
      case DeviceOs.android:
        return 'Android';
      case DeviceOs.ios:
        return 'iOS';
    }
  }
}
