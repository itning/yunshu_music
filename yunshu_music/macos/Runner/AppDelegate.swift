import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
        for window: AnyObject in NSApplication.shared.windows {
            window.makeKeyAndOrderFront(self)
        }
    }
    return true
  }
}
