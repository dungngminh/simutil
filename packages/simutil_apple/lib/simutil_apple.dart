/// Apple simulator and device APIs for SimUtil via simctl and devicectl.
///
/// Lists iPhone/iPad/Watch/TV simulators and connected hardware, plus
/// Xcode Derived Data helpers, simulator screen recording, and slimming
/// ([SimulatorSlimmer]) so more simulators fit in memory.
///
/// ```dart
/// import 'package:simutil_apple/simutil_apple.dart';
/// import 'package:simutil_core/simutil_core.dart';
///
/// final apple = IOSDeviceService(CommandExec());
/// final sims = await apple.getSimulators();
/// ```
library;

export 'src/ios_device_service.dart';
export 'src/simulator_recorder.dart';
export 'src/slim/simulator_slimmer.dart';
export 'src/slim/slim_categories.dart';
export 'src/xcode_cache_service.dart';
