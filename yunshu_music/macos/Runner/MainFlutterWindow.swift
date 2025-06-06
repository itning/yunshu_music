import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    //let windowFrame = self.frame
    self.contentViewController = flutterViewController
    //self.setFrame(windowFrame, display: true)
    self.setFrame(NSRect(x:0, y:0, width: 1200, height: 900), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
