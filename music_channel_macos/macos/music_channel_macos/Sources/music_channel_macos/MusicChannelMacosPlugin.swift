import AVFoundation
import Cocoa
import FlutterMacOS

public class MusicChannelMacosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let player = AVPlayer()
  private var eventSink: FlutterEventSink?
  private var itemStatusObserver: NSKeyValueObservation?
  private var playerStateObserver: NSKeyValueObservation?
  private var endObserver: NSObjectProtocol?
  private var periodicTimeObserver: Any?
  private var shellChannel: FlutterMethodChannel?
  private var statusItem: NSStatusItem?
  private var trayMenu: NSMenu?
  private var titleMenuItem: NSMenuItem?
  private var playMenuItem: NSMenuItem?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MusicChannelMacosPlugin()
    let channel = FlutterMethodChannel(name: "music_channel_macos", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    let audioChannel = FlutterMethodChannel(name: "music_channel_macos/audio", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: audioChannel)
    let events = FlutterEventChannel(name: "music_channel_macos/audio/events", binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)
    let shellChannel = FlutterMethodChannel(name: "music_channel_macos/shell", binaryMessenger: registrar.messenger)
    instance.shellChannel = shellChannel
    registrar.addMethodCallDelegate(instance, channel: shellChannel)
  }

  public override init() {
    super.init()
    playerStateObserver = player.observe(\AVPlayer.timeControlStatus, options: [.new]) { [weak self] player, _ in
      self?.emit(["event": "state", "playing": player.timeControlStatus == .playing])
    }
    periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
      guard time.isValid else { return }
      self?.emit(["event": "position", "positionMs": Int(time.seconds * 1000)])
    }
  }

  deinit { disposePlayer() }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion": result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "setSource": load(arguments: call.arguments, autoplay: false, result: result)
    case "play": load(arguments: call.arguments, autoplay: true, result: result)
    case "resume": player.play(); result(nil)
    case "pause": player.pause(); result(nil)
    case "seek":
      let milliseconds = (call.arguments as? [String: Any])?["positionMs"] as? Int ?? 0
      player.seek(to: CMTime(value: CMTimeValue(milliseconds), timescale: 1000)) { [weak self] _ in self?.emit(["event": "seekComplete"]) }
      result(nil)
    case "setVolume":
      if let volume = (call.arguments as? [String: Any])?["volume"] as? Double { player.volume = Float(volume) }
      result(nil)
    case "dispose": disposePlayer(); result(nil)
    case "initialize":
      DispatchQueue.main.async { [weak self] in
        self?.configureShell(arguments: call.arguments)
        result(nil)
      }
    case "setTitle":
      DispatchQueue.main.async { [weak self] in
        self?.hostWindow?.title = (call.arguments as? [String: Any])?["title"] as? String ?? "云舒音乐"
        result(nil)
      }
    case "setMinimumSize":
      DispatchQueue.main.async { [weak self] in
        let arguments = call.arguments as? [String: Any]
        let width = (arguments?["width"] as? NSNumber)?.doubleValue ?? 450
        let height = (arguments?["height"] as? NSNumber)?.doubleValue ?? 900
        self?.hostWindow?.minSize = NSSize(width: width, height: height)
        result(nil)
      }
    case "showWindow":
      DispatchQueue.main.async { [weak self] in self?.showWindow(); result(nil) }
    case "hideWindow":
      DispatchQueue.main.async { [weak self] in self?.hostWindow?.orderOut(nil); result(nil) }
    case "updateTray":
      DispatchQueue.main.async { [weak self] in
        self?.updateTray(arguments: call.arguments)
        result(nil)
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { eventSink = events; return nil }
  public func onCancel(withArguments arguments: Any?) -> FlutterError? { eventSink = nil; return nil }

  private func load(arguments: Any?, autoplay: Bool, result: @escaping FlutterResult) {
    guard let rawURL = (arguments as? [String: Any])?["url"] as? String, let url = URL(string: rawURL) else {
      result(FlutterError(code: "INVALID_URL", message: "A valid playback URL is required", details: nil)); return
    }
    clearItemObservers()
    let item = AVPlayerItem(url: url)
    itemStatusObserver = item.observe(\AVPlayerItem.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      if item.status == .readyToPlay {
        let seconds = item.duration.seconds
        self.emit(["event": "prepared", "durationMs": seconds.isFinite ? Int(seconds * 1000) : NSNull()])
      } else if item.status == .failed {
        self.emit(["event": "error", "message": item.error?.localizedDescription ?? "Unable to load audio"])
      }
    }
    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in self?.emit(["event": "complete"]) }
    player.replaceCurrentItem(with: item)
    if autoplay { player.play() }
    result(nil)
  }

  private func clearItemObservers() {
    itemStatusObserver?.invalidate(); itemStatusObserver = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
  }

  private func disposePlayer() {
    player.pause(); player.replaceCurrentItem(with: nil); clearItemObservers()
    playerStateObserver?.invalidate(); playerStateObserver = nil
    if let periodicTimeObserver { player.removeTimeObserver(periodicTimeObserver) }
    periodicTimeObserver = nil
  }

  private func emit(_ event: [String: Any]) { eventSink?(event) }

  private var hostWindow: NSWindow? {
    NSApplication.shared.windows.first { $0.contentViewController is FlutterViewController }
      ?? NSApplication.shared.mainWindow
  }

  private func configureShell(arguments: Any?) {
    let values = arguments as? [String: Any]
    let title = values?["title"] as? String ?? "云舒音乐"
    let width = (values?["minWidth"] as? NSNumber)?.doubleValue ?? 450
    let height = (values?["minHeight"] as? NSNumber)?.doubleValue ?? 900
    hostWindow?.title = title
    hostWindow?.minSize = NSSize(width: width, height: height)
    configureStatusItem()
  }

  private func configureStatusItem() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let icon = NSApp.applicationIconImage {
      icon.size = NSSize(width: 18, height: 18)
      icon.isTemplate = false
      item.button?.image = icon
    }
    item.button?.target = self
    item.button?.action = #selector(handleStatusItemClick(_:))
    item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    statusItem = item

    let menu = NSMenu()
    let titleItem = menuItem(title: "云舒音乐", action: "show")
    menu.addItem(titleItem)
    titleMenuItem = titleItem
    menu.addItem(.separator())
    menu.addItem(menuItem(title: "上一曲", action: "previous"))
    menu.addItem(menuItem(title: "下一曲", action: "next"))
    let playItem = menuItem(title: "播放", action: "toggle")
    menu.addItem(playItem)
    playMenuItem = playItem
    menu.addItem(.separator())
    menu.addItem(menuItem(title: "退出", action: "quit"))
    trayMenu = menu
  }

  private func menuItem(title: String, action: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
    item.target = self
    item.representedObject = action
    return item
  }

  private func updateTray(arguments: Any?) {
    let values = arguments as? [String: Any]
    titleMenuItem?.title = values?["title"] as? String ?? "云舒音乐"
    statusItem?.button?.toolTip = values?["tooltip"] as? String
    let isPlaying = values?["isPlaying"] as? Bool ?? false
    playMenuItem?.title = isPlaying ? "暂停" : "播放"
  }

  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp, let menu = trayMenu {
      menu.popUp(positioning: nil, at: .zero, in: sender)
      return
    }
    guard let window = hostWindow else { return }
    if window.isVisible { window.orderOut(nil) } else { showWindow() }
  }

  @objc private func handleMenuAction(_ sender: NSMenuItem) {
    guard let action = sender.representedObject as? String else { return }
    shellChannel?.invokeMethod("trayAction", arguments: action)
  }

  private func showWindow() {
    guard let window = hostWindow else { return }
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}
