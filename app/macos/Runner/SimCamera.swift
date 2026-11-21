// Camera feeds for iOS Simulator apps. A simulator has no camera, so an app
// is launched with libSimCameraInjector.dylib (serve-sim, see
// ../SimCameraInjector/NOTICE) inserted; the dylib swizzles AVFoundation and
// reads frames from a SimCameraFeed this plugin runs, one per simulator.
//
// Channel `simutil/sim_camera`:
//   webcams → [{id, name}]
//   start(udid, source, arg) → {shm, dylib}; source webcam / image / video,
//     arg the webcam id or file path. Hot-swaps a running feed.
//   status(udid) → {source, arg} or nil
//   stop(udid)

import AVFoundation
import Cocoa
import FlutterMacOS

final class SimCameraPlugin: NSObject, FlutterPlugin {
  /// Touched only on [queue]: switching sources blocks on AVCaptureSession,
  /// which needs the main thread free.
  private var feeds: [String: SimCameraFeed] = [:]
  private let queue = DispatchQueue(label: "simutil.camera.plugin")

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "simutil/sim_camera", binaryMessenger: registrar.messenger)
    let plugin = SimCameraPlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: nil
    ) { _ in
      // Unlink the shm names so they do not outlive the app.
      plugin.queue.sync {
        plugin.feeds.values.forEach { $0.stop() }
        plugin.feeds.removeAll()
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    switch call.method {
    case "webcams":
      result(SimCameraFeed.webcams())
    case "start":
      guard let udid = args["udid"] as? String, let source = args["source"] as? String else {
        return result(FlutterError(code: "args", message: "udid and source required", details: nil))
      }
      let arg = args["arg"] as? String
      Task {
        if source == "webcam", !(await AVCaptureDevice.requestAccess(for: .video)) {
          return reply(
            FlutterError(
              code: "camera",
              message:
                "SimUtil needs Camera access to use your webcam: allow it in System Settings › Privacy & Security › Camera",
              details: nil))
        }
        queue.async { reply(self.start(udid: udid, source: source, arg: arg)) }
      }
    case "status":
      guard let udid = args["udid"] as? String else { return result(nil) }
      queue.async {
        reply(self.feeds[udid].map { ["source": $0.source, "arg": $0.arg] as [String: Any?] })
      }
    case "stop":
      guard let udid = args["udid"] as? String else { return result(nil) }
      queue.async {
        self.feeds.removeValue(forKey: udid)?.stop()
        reply(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(udid: String, source: String, arg: String?) -> Any {
    guard
      let dylib = Bundle.main.path(forResource: "libSimCameraInjector", ofType: "dylib")
    else {
      return FlutterError(code: "start", message: "libSimCameraInjector.dylib is missing", details: nil)
    }
    // ponytail: POSIX shm names are capped at 31 chars, so the UDID's first
    // 8 hex digits; hash the full UDID if two simulators ever collide.
    let shm = "/simutil-cam-\(udid.prefix(8))"
    let feed: SimCameraFeed
    if let running = feeds[udid] {
      feed = running
    } else if let created = SimCameraFeed(shmName: shm) {
      feed = created
    } else {
      return FlutterError(
        code: "start", message: "Could not create the camera feed", details: nil)
    }
    if let error = feed.switch(toSource: source, arg: arg) {
      if feeds[udid] == nil { feed.stop() }
      return FlutterError(code: "start", message: error, details: nil)
    }
    feeds[udid] = feed
    return ["shm": shm, "dylib": dylib]
  }
}
