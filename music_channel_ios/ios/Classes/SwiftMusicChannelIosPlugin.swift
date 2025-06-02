import Flutter
import UIKit
import AVFoundation
import MediaPlayer

public class SwiftMusicChannelIosPlugin: NSObject, FlutterPlugin {

  static var channel:FlutterMethodChannel?

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
}
