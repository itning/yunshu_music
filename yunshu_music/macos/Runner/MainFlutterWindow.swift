import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private enum WindowDefaultsKey {
    static let width = "MainFlutterWindow.width"
    static let height = "MainFlutterWindow.height"
  }

  private var dockMenuChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(origin: .zero, size: savedWindowSize()), display: true)
    self.center()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResize(_:)),
      name: NSWindow.didResizeNotification,
      object: self
    )

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureDockMenuChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func windowDidResize(_ notification: Notification) {
    UserDefaults.standard.set(frame.width, forKey: WindowDefaultsKey.width)
    UserDefaults.standard.set(frame.height, forKey: WindowDefaultsKey.height)
  }

  private func savedWindowSize() -> NSSize {
    let defaults = UserDefaults.standard
    let width = defaults.double(forKey: WindowDefaultsKey.width)
    let height = defaults.double(forKey: WindowDefaultsKey.height)

    guard width > 0, height > 0 else {
      return frame.size
    }
    return NSSize(width: width, height: height)
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
