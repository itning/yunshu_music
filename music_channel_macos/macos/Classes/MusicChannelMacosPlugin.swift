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

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MusicChannelMacosPlugin()
    let channel = FlutterMethodChannel(name: "music_channel_macos", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    let audioChannel = FlutterMethodChannel(name: "music_channel_macos/audio", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: audioChannel)
    let events = FlutterEventChannel(name: "music_channel_macos/audio/events", binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)
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
}
