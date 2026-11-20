import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Asks the main window's engine to release streams, recordings and
  /// child processes (`releaseApp` in Dart); it closes the device windows.
  private var quitChannel: FlutterMethodChannel? {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return nil }
    return FlutterMethodChannel(
      name: "simutil/quit", binaryMessenger: controller.engine.binaryMessenger)
  }

  /// The release ran (or gave up); the next terminate goes through.
  private var released = false
  private var releasing = false

  /// A hung release must not keep the app from quitting.
  private static let releaseTimeout: TimeInterval = 10

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  /// Cmd+Q, the app menu, the Dock and logging out terminate without
  /// closing the window, so the Dart side never hears of it: adb, scrcpy
  /// and ffmpeg would keep running. Cancel, release, then terminate again.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !released, let channel = quitChannel else { return .terminateNow }
    if releasing { return .terminateCancel }
    releasing = true
    let finish = { [weak self] in
      guard let self, !self.released else { return }
      self.released = true
      sender.terminate(nil)
    }
    channel.invokeMethod("release", arguments: nil) { _ in finish() }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.releaseTimeout, execute: finish)
    return .terminateCancel
  }

  /// The Dock icon shows the main window again after it was hidden while
  /// device windows stayed open.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    if let window = mainFlutterWindow, !window.isVisible {
      window.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
