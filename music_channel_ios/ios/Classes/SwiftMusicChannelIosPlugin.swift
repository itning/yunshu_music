import Flutter
import UIKit
import AVFoundation
import MediaPlayer

public class SwiftMusicChannelIosPlugin: NSObject, FlutterPlugin {

  static var channel:FlutterMethodChannel?

  override init() {
    super.init()
    let session = AVAudioSession.sharedInstance()
    // 添加中断监听
    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: session)
    // 监听音频路由变化（如耳机插入/拔出）
    NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: session)
  }

  deinit {
    let session = AVAudioSession.sharedInstance()
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: session)
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: session)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "music_channel_ios", binaryMessenger: registrar.messenger())
    let instance = SwiftMusicChannelIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel!)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     switch call.method {
     case "init":
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
        } catch {
            print(error)
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()

        let commandCenter = MPRemoteCommandCenter.shared()

        // 监听播放/暂停事件
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget(self, action: #selector(playButtonTapped))
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseButtonTapped))

        // 监听下一曲/上一曲事件
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextButtonTapped))
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(previousButtonTapped))

        // 监听进度条拖动事件
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(seekToTime(_:)))

        // 监听播放/暂停切换事件
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseButtonTapped))

        result(nil)

     case "setLockScreenDisplay":
        if let args = call.arguments as? Dictionary<String, Any> {
            DispatchQueue.global().async {

                        var data:Data?
                        do{
                            if let url = URL(string: args["coverUri"] as? String ?? ""){
                                data = try Data(contentsOf: url)
                            }
                        }catch let error{
                            print("get cover iamge failed \(error)")
                        }

                        DispatchQueue.main.async {
                            if data != nil {
                                let image =  UIImage(data: data!)!
                                let metadata: [String: Any] = [
                                    MPMediaItemPropertyTitle:args["name"] as? String ?? "",
                                    MPMediaItemPropertyArtist: args["singer"] as? String ?? "",
                                    MPMediaItemPropertyAlbumTitle: args["singer"] as? String ?? "",
                                    MPMediaItemPropertyPlaybackDuration: args["duration"] as? Int ?? 0,
                                    MPNowPlayingInfoPropertyPlaybackRate: 1.0,
                                    MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: image)
                                ]
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata
                            }else{
                                let metadata: [String: Any] = [
                                    MPMediaItemPropertyTitle: args["name"] as? String ?? "",
                                    MPMediaItemPropertyArtist: args["singer"] as? String ?? "",
                                    MPMediaItemPropertyAlbumTitle: args["singer"] as? String ?? "",
                                    MPMediaItemPropertyPlaybackDuration: args["duration"] as? Int ?? 0,
                                    MPNowPlayingInfoPropertyPlaybackRate: 1.0
                                ]
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata
                            }
                        }
                    }
            result(nil)
        } else {
            result(FlutterError.init(code: "error setLockScreenDisplay", message: "data or format error", details: nil))
        }

     case "setLockScreenDisplayTime":
          if let args = call.arguments as? Dictionary<String, Any> {
                  let duration = args["duration"] as? Int ?? 0

                  let elapsedTime = args["time"] as? Int ?? 0

                  var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                  nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
                  nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime

                  MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                  result(nil)
          } else {
             result(FlutterError.init(code: "error setLockScreenDisplayTime", message: "data or format error", details: nil))
          }

     case "changeToPlaying":
         MPNowPlayingInfoCenter.default().playbackState  = MPNowPlayingPlaybackState.playing
         result(nil)

     case "changeToPaused":
         MPNowPlayingInfoCenter.default().playbackState  = MPNowPlayingPlaybackState.paused
         result(nil)

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
      // 获取用户拖动到的时间点（秒）
      let seekTime = Int(positionEvent.positionTime)
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("seekTo", arguments: ["position": seekTime])
       return MPRemoteCommandHandlerStatus.success
  }

  @objc func togglePlayPauseButtonTapped(_ event: Any) -> MPRemoteCommandHandlerStatus {
      SwiftMusicChannelIosPlugin.channel?.invokeMethod("togglePlayPause", arguments: nil)
      return MPRemoteCommandHandlerStatus.success
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
}
