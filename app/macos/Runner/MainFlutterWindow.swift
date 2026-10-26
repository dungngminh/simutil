import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    registerPlugins(flutterViewController)
    // Device windows run their own engine and need every plugin too.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      registerPlugins(controller)
    }

    super.awakeFromNib()
  }
}

private func registerPlugins(_ controller: FlutterViewController) {
  RegisterGeneratedPlugins(registry: controller)
  SimStreamPlugin.register(
    with: controller.registrar(forPlugin: "SimStreamPlugin"))
  DeviceStreamPlugin.register(
    with: controller.registrar(forPlugin: "DeviceStreamPlugin"))
  SimCameraPlugin.register(
    with: controller.registrar(forPlugin: "SimCameraPlugin"))
  WindowRecorderPlugin.register(
    with: controller.registrar(forPlugin: "WindowRecorderPlugin"))
}
