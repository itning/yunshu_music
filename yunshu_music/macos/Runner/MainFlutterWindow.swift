import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var dockMenuChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    //let windowFrame = self.frame
    self.contentViewController = flutterViewController
    //self.setFrame(windowFrame, display: true)
    self.setFrame(NSRect(x:0, y:0, width: 1200, height: 900), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureDockMenuChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  func sendDockMenuAction(_ action: String) {
    dockMenuChannel?.invokeMethod("dockMenuAction", arguments: action)
  }

  private func configureDockMenuChannel(for controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "yunshu.music/dock_menu",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "updateDockMenu" else {
        result(FlutterMethodNotImplemented)
        return
      }
      (NSApp.delegate as? AppDelegate)?.updateDockMenuState(
        with: call.arguments as? [String: Any]
      )
      result(nil)
    }
    dockMenuChannel = channel
  }
}
