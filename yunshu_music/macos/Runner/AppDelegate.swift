import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var dockMenuState = DockMenuState()

  func updateDockMenuState(with values: [String: Any]?) {
    dockMenuState.update(with: values)
  }

  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    if !dockMenuState.title.isEmpty || !dockMenuState.artist.isEmpty {
      let nowPlaying = NSMenuItem(title: dockMenuState.nowPlayingTitle, action: nil, keyEquivalent: "")
      nowPlaying.isEnabled = false
      menu.addItem(nowPlaying)
      menu.addItem(.separator())
    }
    menu.addItem(dockMenuItem(title: "上一首", action: "previous", enabled: dockMenuState.canSkipPrevious))
    menu.addItem(dockMenuItem(title: dockMenuState.isPlaying ? "暂停" : "播放", action: "toggle", enabled: true))
    menu.addItem(dockMenuItem(title: "下一首", action: "next", enabled: dockMenuState.canSkipNext))
    menu.addItem(.separator())
    menu.addItem(dockMenuItem(title: "打开主窗口", action: "show", enabled: true))
    return menu
  }

  private func dockMenuItem(title: String, action: String, enabled: Bool) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(handleDockMenuAction(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = action
    item.isEnabled = enabled
    return item
  }

  @objc private func handleDockMenuAction(_ sender: NSMenuItem) {
    guard let action = sender.representedObject as? String else { return }
    (mainFlutterWindow as? MainFlutterWindow)?.sendDockMenuAction(action)
  }

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

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

private struct DockMenuState {
  var title = ""
  var artist = ""
  var isPlaying = false
  var canSkipPrevious = false
  var canSkipNext = false

  var nowPlayingTitle: String {
    if title.isEmpty { return artist }
    if artist.isEmpty { return title }
    return "正在播放：\(title) - \(artist)"
  }

  mutating func update(with values: [String: Any]?) {
    title = values?["title"] as? String ?? ""
    artist = values?["artist"] as? String ?? ""
    isPlaying = values?["isPlaying"] as? Bool ?? false
    canSkipPrevious = values?["canSkipPrevious"] as? Bool ?? false
    canSkipNext = values?["canSkipNext"] as? Bool ?? false
  }
}
