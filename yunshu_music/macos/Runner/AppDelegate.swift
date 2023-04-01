import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
    
    var methodChannel:FlutterMethodChannel?
    
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
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "yunshu.music/method_channel", binaryMessenger: controller.engine.binaryMessenger)
        methodChannel!.setMethodCallHandler(handlerCall)
        let playbackStateEventChannel = FlutterEventChannel(name: "yunshu.music/playback_state_event_channel", binaryMessenger: controller.engine.binaryMessenger)
        let metadataEventChannel = FlutterEventChannel(name: "yunshu.music/metadata_event_channel", binaryMessenger: controller.engine.binaryMessenger)
        playbackStateEventChannel.setStreamHandler(PlaybackStateEvent.INSTANCE)
        metadataEventChannel.setStreamHandler(MetadataEvent.INSTANCE)
        
    }
    
    func handlerCall(_ call: FlutterMethodCall, _ result: FlutterResult) -> Void {
        switch call.method{
        case "init":
            print("init")
            methodChannel?.invokeMethod("getMusicList", arguments: nil, result: { response in
                //print(response ?? "")
                if response == nil {
                    return
                }
                let di = response! as? [Dictionary<String,Any>]
                if di == nil {
                    return
                }
                let musicList:[Music] = di!.map({ Music(
                    musicId: $0["musicId"] as? String ?? "",
                    name: $0["name"] as? String ?? "",
                    singer: $0["singer"] as? String ?? "",
                    lyricId: $0["lyricId"] as? String ?? "",
                    type: $0["type"] as? Int ?? 0,
                    musicUri: $0["musicUri"] as? String ?? "",
                    lyricUri: $0["lyricUri"] as? String ?? "",
                    coverUri: $0["coverUri"] as? String ?? ""
                ) })
                MusicPlayDataService.INSTANCE.addMusic(musicList: musicList)
                if let musicId = MusicPlayDataService.INSTANCE.getNowPlayMusic()?.musicId{
                    MediaPlayerImpl.INSTANCE.playFromMediaId(musicId: musicId)
                }
                
            })
            result(nil)
        case "playFromId":
            print("playFromId")
            if let args = call.arguments as? Dictionary<String, Any>,
               let id = args["id"] as? String {
                MediaPlayerImpl.INSTANCE.playFromMediaId(musicId: id)
                result(nil)
            } else {
                result(FlutterError.init(code: "error playFromId", message: "data or format error", details: nil))
            }
           
        case "play":
            print("play")
            MediaPlayerImpl.INSTANCE.play()
            result(nil)
            
        case "pause":
            print("pause")
            MediaPlayerImpl.INSTANCE.pause()
            result(nil)
            
        case "seekTo":
            print("seekTo")
            if let args = call.arguments as? Dictionary<String, Any>,
               let seek = args["position"] as? Int {
                MediaPlayerImpl.INSTANCE.seekTo(seek:seek)
                result(nil)
            } else {
                result(FlutterError.init(code: "error seekTo", message: "data or format error", details: nil))
            }
            
        case "skipToPrevious":
            print("skipToPrevious")
            MediaPlayerImpl.INSTANCE.skipToPrevious()
            result(nil)
        case "skipToNext":
            print("skipToNext")
            MediaPlayerImpl.INSTANCE.skipToNext()
            result(nil)
        case "setPlayMode":
            print("setPlayMode")
            if let args = call.arguments as? Dictionary<String, Any>,
               let mode = args["mode"] as? String {
                MusicPlayDataService.INSTANCE.setPlayMode(playMode:MusicPlayMode.valueOf(mode.uppercased()))
                result(nil)
            } else {
                result(FlutterError.init(code: "error setPlayMode", message: "data or format error", details: nil))
            }
            
        case "getPlayMode":
            print("getPlayMode")
            result(MusicPlayDataService.INSTANCE.getPlayMode().rawValue.lowercased())
            
        case "getPlayList":
            let playList = MusicPlayDataService.INSTANCE.getPlayList().map({ ["mediaId":$0.musicId,"title":$0.name,"subTitle":$0.singer] })
            result(playList)
            
        case "delPlayListByMediaId":
            print("delPlayListByMediaId")
            if let args = call.arguments as? Dictionary<String, Any>,
               let mediaId = args["mediaId"] as? String {
                MusicPlayDataService.INSTANCE.delPlayListByMediaId(mediaId: mediaId)
                result(nil)
            } else {
                result(FlutterError.init(code: "error delPlayListByMediaId", message: "data or format error", details: nil))
            }
            
        case "clearPlayList":
            print("clearPlayList")
            MusicPlayDataService.INSTANCE.clearPlayList()
            result(nil)
        default:
            print("call \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
}
