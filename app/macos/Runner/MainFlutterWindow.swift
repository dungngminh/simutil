import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    SimStreamPlugin.register(
      with: flutterViewController.registrar(forPlugin: "SimStreamPlugin"))
    DeviceStreamPlugin.register(
      with: flutterViewController.registrar(forPlugin: "DeviceStreamPlugin"))
    SimCameraPlugin.register(
      with: flutterViewController.registrar(forPlugin: "SimCameraPlugin"))
    WindowRecorderPlugin.register(
      with: flutterViewController.registrar(forPlugin: "WindowRecorderPlugin"))

    super.awakeFromNib()
  }
}
