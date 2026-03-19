enum DeviceOs {
  android,
  ios;

  String get label {
    switch (this) {
      case DeviceOs.android:
        return 'Android';
      case DeviceOs.ios:
        return 'iOS';
    }
  }
}
