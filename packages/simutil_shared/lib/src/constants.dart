/// Fallback device-list reload period; changes normally arrive through
/// `DeviceService.watchDevices` (see `DeviceChangeWatcher`).
const kReloadInterval = Duration(seconds: 60);

/// Extra refresh delay after launch/shutdown so status can settle.
const kReloadAfterActionInterval = Duration(seconds: 2);
