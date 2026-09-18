import Flutter
import UIKit
import AVFoundation
import MediaPlayer

public class SwiftMusicChannelIosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  static var channel:FlutterMethodChannel?
  private let player = AVPlayer()
  private var audioEventSink: FlutterEventSink?
  private var itemStatusObserver: NSKeyValueObservation?
  private var playerStateObserver: NSKeyValueObservation?
  private var endObserver: NSObjectProtocol?
  private var periodicTimeObserver: Any?
  private var remoteCommandsConfigured = false
  private var artworkTask: URLSessionDataTask?
  private var artworkRequestID = UUID()

  override init() {
    super.init()
    let session = AVAudioSession.sharedInstance()
    // 添加中断监听
    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: session)
    // 监听音频路由变化（如耳机插入/拔出）
    NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: session)
    playerStateObserver = player.observe(\AVPlayer.timeControlStatus, options: [.new]) { [weak self] player, _ in
      self?.syncNowPlayingTimeline()
      self?.emitAudio(["event": "state", "playing": player.timeControlStatus == .playing])
    }
    periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
      guard time.isValid else { return }
      self?.syncNowPlayingTimeline(position: time.seconds)
      self?.emitAudio(["event": "position", "positionMs": Int(time.seconds * 1000)])
    }
  }

  deinit {
    let session = AVAudioSession.sharedInstance()
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: session)
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: session)
    clearCurrentItem()
    playerStateObserver?.invalidate()
    if let periodicTimeObserver { player.removeTimeObserver(periodicTimeObserver) }
    artworkTask?.cancel()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "music_channel_ios", binaryMessenger: registrar.messenger())
    let instance = SwiftMusicChannelIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel!)
    let audioChannel = FlutterMethodChannel(name: "music_channel_ios/audio", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: audioChannel)
    FlutterEventChannel(name: "music_channel_ios/audio/events", binaryMessenger: registrar.messenger()).setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     switch call.method {
     case "setSource":
        loadAudio(arguments: call.arguments, autoplay: false, result: result)
     case "play":
        loadAudio(arguments: call.arguments, autoplay: true, result: result)
     case "resume":
        player.play(); result(nil)
     case "pause":
        player.pause(); result(nil)
     case "seek":
        let milliseconds = (call.arguments as? [String: Any])?["positionMs"] as? Int ?? 0
        player.seek(to: CMTime(value: CMTimeValue(milliseconds), timescale: 1000)) { [weak self] completed in
          guard completed else { return }
          self?.syncNowPlayingTimeline(position: Double(milliseconds) / 1000)
          self?.emitAudio(["event": "position", "positionMs": milliseconds])
          self?.emitAudio(["event": "seekComplete"])
        }
        result(nil)
     case "setVolume":
        if let volume = (call.arguments as? [String: Any])?["volume"] as? Double { player.volume = Float(volume) }
        result(nil)
     case "dispose":
        clearCurrentItem(); result(nil)
     case "init", "initializeMediaSession":
        configureMediaSession(result: result)
     case "updateNowPlaying":
        updateNowPlaying(arguments: call.arguments, result: result)
     case "updatePlaybackOptions":
        updatePlaybackOptions(arguments: call.arguments, result: result)

     default:
         print("call \(call.method)")
         result(FlutterMethodNotImplemented)

     }
    //result("iOS " + UIDevice.current.systemVersion)
  }

  @objc func playButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("playButtonTapped",  arguments: nil)
      return MPRemoteCommandHandlerStatus.success
  }

  @objc func pauseButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("pauseButtonTapped",  arguments: nil)
      return MPRemoteCommandHandlerStatus.success
  }

  @objc func nextButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("nextButtonTapped",  arguments: nil)
      return MPRemoteCommandHandlerStatus.success
  }

  @objc func previousButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("previousButtonTapped",  arguments: nil)
      return MPRemoteCommandHandlerStatus.success
  }

  @objc func seekToTime(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
      guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
          return MPRemoteCommandHandlerStatus.commandFailed
      }
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("seekTo", arguments: ["positionMs": Int(positionEvent.positionTime * 1000)])
       return MPRemoteCommandHandlerStatus.success
  }

  @objc func togglePlayPauseButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("togglePlayPause", arguments: nil)
      return MPRemoteCommandHandlerStatus.success
  }

  @objc func shuffleModeChanged(_ event: MPChangeShuffleModeCommandEvent) -> MPRemoteCommandHandlerStatus {
      let enabled = event.shuffleType == .items
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("shuffleChanged", arguments: ["enabled": enabled])
      return .success
  }

  @objc func repeatModeChanged(_ event: MPChangeRepeatModeCommandEvent) -> MPRemoteCommandHandlerStatus {
      let mode: String
      switch event.repeatType {
      case .one: mode = "one"
      case .all: mode = "all"
      default: mode = "off"
      }
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("repeatChanged", arguments: ["mode": mode])
      return .success
  }

  @objc func skipForward(_ event: MPSkipIntervalCommandEvent) -> MPRemoteCommandHandlerStatus {
      return skip(by: event.interval)
  }

  @objc func skipBackward(_ event: MPSkipIntervalCommandEvent) -> MPRemoteCommandHandlerStatus {
      return skip(by: -event.interval)
  }

  @objc func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }

    if type == .began {
        // 中断开始：通知 Flutter 层暂停播放
        SwiftMusicChannelIosPlugin.channel?.invokeMethod("audioInterruptionBegan", arguments: nil)
    } else if type == .ended {
        // 中断结束：是否需要恢复播放
        SwiftMusicChannelIosPlugin.channel?.invokeMethod("audioInterruptionEnded", arguments: nil)
        
        // 如果系统建议恢复播放
        guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
            SwiftMusicChannelIosPlugin.channel?.invokeMethod("audioInterruptionShouldResume", arguments: nil)
        }
    }
 }

 @objc func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
        return
    }

    switch reason {
    case .newDeviceAvailable:
        print("有新设备接入，比如插入耳机")
        
    case .oldDeviceUnavailable:
        print("旧设备不可用，比如拔出耳机")
        if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
            for output in previousRoute.outputs {
                if output.portType == .headphones {
                    // 真的是耳机拔出
                    SwiftMusicChannelIosPlugin.channel?.invokeMethod("headphonesUnplugged", arguments: nil)
                }
            }
        }
        
    case .categoryChange:
        print("音频会话类别改变")
        
    case .override:
        print("输出被覆盖（如 AirPlay）")
        
    case .wakeFromSleep:
        print("从休眠中唤醒")

    case .noSuitableRouteForCategory:
        print("没有合适的音频路线可用")
    
    case .routeConfigurationChange:
        print("routeConfigurationChange")

    @unknown default:
        break
    }
 }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    audioEventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    audioEventSink = nil
    return nil
  }

  private func loadAudio(arguments: Any?, autoplay: Bool, result: @escaping FlutterResult) {
    guard let rawURL = (arguments as? [String: Any])?["url"] as? String, let url = URL(string: rawURL) else {
      result(FlutterError(code: "INVALID_URL", message: "A valid playback URL is required", details: nil))
      return
    }
    clearItemObservers()
    let item = AVPlayerItem(url: url)
    itemStatusObserver = item.observe(\AVPlayerItem.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      if item.status == .readyToPlay {
        let seconds = item.duration.seconds
        self.emitAudio(["event": "prepared", "durationMs": seconds.isFinite ? Int(seconds * 1000) : NSNull()])
      } else if item.status == .failed {
        self.emitAudio(["event": "error", "message": item.error?.localizedDescription ?? "Unable to load audio"])
      }
    }
    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in self?.emitAudio(["event": "complete"]) }
    player.replaceCurrentItem(with: item)
    syncNowPlayingTimeline(position: 0)
    if autoplay { player.play() }
    result(nil)
  }

  private func clearItemObservers() {
    itemStatusObserver?.invalidate(); itemStatusObserver = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
  }

  private func clearCurrentItem() {
    player.pause(); player.replaceCurrentItem(with: nil); clearItemObservers()
  }

  private func configureMediaSession(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
      UIApplication.shared.beginReceivingRemoteControlEvents()
      configureRemoteCommands()
      result(nil)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION", message: error.localizedDescription, details: nil))
    }
  }

  private func configureRemoteCommands() {
    guard !remoteCommandsConfigured else { return }
    remoteCommandsConfigured = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.playCommand.addTarget(self, action: #selector(playButtonTapped))
    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget(self, action: #selector(pauseButtonTapped))
    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseButtonTapped))
    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget(self, action: #selector(nextButtonTapped))
    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget(self, action: #selector(previousButtonTapped))
    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget(self, action: #selector(seekToTime(_:)))
    center.skipForwardCommand.isEnabled = true
    center.skipForwardCommand.preferredIntervals = [15]
    center.skipForwardCommand.addTarget(self, action: #selector(skipForward(_:)))
    center.skipBackwardCommand.isEnabled = true
    center.skipBackwardCommand.preferredIntervals = [15]
    center.skipBackwardCommand.addTarget(self, action: #selector(skipBackward(_:)))
    center.changeShuffleModeCommand.isEnabled = true
    center.changeShuffleModeCommand.addTarget(self, action: #selector(shuffleModeChanged(_:)))
    center.changeRepeatModeCommand.isEnabled = true
    center.changeRepeatModeCommand.addTarget(self, action: #selector(repeatModeChanged(_:)))
  }

  private func updateNowPlaying(arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any] else {
      result(FlutterError(code: "NOW_PLAYING_ARGUMENTS", message: "Expected Now Playing metadata.", details: nil))
      return
    }
    let duration = (arguments["durationMs"] as? NSNumber)?.doubleValue ?? 0
    let queueIndex = (arguments["queueIndex"] as? NSNumber)?.intValue ?? 0
    let queueCount = (arguments["queueCount"] as? NSNumber)?.intValue ?? 0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: arguments["title"] as? String ?? "",
      MPMediaItemPropertyArtist: arguments["artist"] as? String ?? "",
      MPMediaItemPropertyPlaybackDuration: duration / 1000,
      MPNowPlayingInfoPropertyPlaybackQueueIndex: queueIndex,
      MPNowPlayingInfoPropertyPlaybackQueueCount: queueCount,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0,
      MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .playing ? player.rate : 0,
    ]
    loadArtwork(from: arguments["artworkUrl"] as? String ?? "")
    result(nil)
  }

  private func updatePlaybackOptions(arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any] else {
      result(FlutterError(code: "PLAYBACK_OPTIONS_ARGUMENTS", message: "Expected playback options.", details: nil))
      return
    }
    let center = MPRemoteCommandCenter.shared()
    center.changeShuffleModeCommand.currentShuffleType = (arguments["shuffle"] as? Bool ?? false) ? .items : .off
    switch arguments["repeatMode"] as? String {
    case "one": center.changeRepeatModeCommand.currentRepeatType = .one
    case "all": center.changeRepeatModeCommand.currentRepeatType = .all
    default: center.changeRepeatModeCommand.currentRepeatType = .off
    }
    result(nil)
  }

  private func syncNowPlayingTimeline(position: Double? = nil) {
    guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
    let elapsed = position ?? player.currentTime().seconds
    guard elapsed.isFinite else { return }
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    info[MPNowPlayingInfoPropertyPlaybackRate] = player.timeControlStatus == .playing ? player.rate : 0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func skip(by interval: TimeInterval) -> MPRemoteCommandHandlerStatus {
    let duration = player.currentItem?.duration.seconds ?? 0
    guard duration.isFinite, duration > 0 else { return .commandFailed }
    let target = min(max(player.currentTime().seconds + interval, 0), duration)
    player.seek(to: CMTime(seconds: target, preferredTimescale: 1000)) { [weak self] completed in
      guard completed else { return }
      self?.syncNowPlayingTimeline(position: target)
      self?.emitAudio(["event": "position", "positionMs": Int(target * 1000)])
      self?.emitAudio(["event": "seekComplete"])
    }
    return .success
  }

  private func loadArtwork(from rawURL: String) {
    artworkTask?.cancel()
    artworkRequestID = UUID()
    let requestID = artworkRequestID
    guard let url = URL(string: rawURL), !rawURL.isEmpty else { return }
    artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let self, requestID == self.artworkRequestID, let data, let image = UIImage(data: data) else { return }
      DispatchQueue.main.async {
        guard requestID == self.artworkRequestID else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }
    artworkTask?.resume()
  }

  private func emitAudio(_ event: [String: Any]) { audioEventSink?(event) }
}
