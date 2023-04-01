import Foundation
import AVFoundation

class MediaPlayerImpl : NSObject{
    public static let INSTANCE = MediaPlayerImpl()
    
    private let player:AVPlayer
    private var playerItem:AVPlayerItem?
    
    private var playNow = false
    
    private var needInit = true
    
    override init(){
        self.player = AVPlayer()
    }
    
    func playFromMediaId(musicId:String) -> Void {
        MusicPlayDataService.INSTANCE.playFromMediaId(mediaId: musicId)
        
        if needInit {
            
            player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
            // 播放进度改变
            player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 5), queue: DispatchQueue.main, using: onTimeChange)
            // 播放结束回调
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main, using: onPlayEnd)

            needInit  = false
        }
        
        initPlay()
    }
    
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        if keyPath == "status" {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            let playItem:AVPlayerItem = object as! AVPlayerItem
            switch status {
            case .readyToPlay:
                print("readyToPlay")
                if let music = MusicPlayDataService.INSTANCE.getNowPlayMusic(){
                    let meta:[String:Any] = [
                        "mediaId":music.musicId,
                        "title":music.name,
                        "subTitle":music.singer,
                        "duration":playItem.duration.toMilliseconds,
                        "musicUri":music.musicUri,
                        "lyricUri":music.lyricUri,
                        "coverUri":music.coverUri
                    ]
                    
                    MetadataEvent.INSTANCE.send(meta)
                    if playNow{
                        self.play()
                    }else{
                        let array = playItem.loadedTimeRanges
                        let timeRange = array.first?.timeRangeValue //本次缓冲时间范围
                        let totalBuffer:Int = timeRange?.toMilliseconds ?? 0
                        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":totalBuffer,"state":2,"position":0])
                        playNow = true
                    }
                }
                
            case .failed:
                // Player item failed. See error.
                PlaybackStateEvent.INSTANCE.send(["bufferedPosition":0,"state":7,"position":0])
                print("failed")
                
            case .unknown:
                // Player item is not yet ready.
                PlaybackStateEvent.INSTANCE.send(["bufferedPosition":0,"state":-1,"position":0])
                print("unknown")
                
            default:
                print("?  \(status)")
                PlaybackStateEvent.INSTANCE.send(["bufferedPosition":0,"state":0,"position":0])
                
            }
            return
        }
        
        if keyPath == "loadedTimeRanges" {
            let playItem:AVPlayerItem = object as! AVPlayerItem
            let totalBuffer:Int = getBufferTime()
            print("缓冲总长度 \(totalBuffer) \(playItem.duration.toMilliseconds)")
            
            var status:Int
            if isPlayingNow(){
                status = 3
            }else{
                status = 2
            }
            PlaybackStateEvent.INSTANCE.send(["bufferedPosition":totalBuffer,"state":status,"position":playItem.currentTime().toMilliseconds])
            return
        }
        
        if keyPath == "timeControlStatus"{
            if let newValue = change?[.newKey] as? Int{
                let newStatus:AVPlayer.TimeControlStatus = AVPlayer.TimeControlStatus(rawValue: newValue)!
                switch newStatus {
                case .paused:
                    PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":2,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
                    print("timeControlStatus paused")
                case .waitingToPlayAtSpecifiedRate:
                    print("waitingToPlayAtSpecifiedRate")
                case .playing:
                    PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":3,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
                    print("timeControlStatus playing")
                default:
                    print("timeControlStatus unknow \(newStatus)")
                }
            }
            return
        }
        
        print("no handler")
    }
    
    func play() -> Void {
        player.play()
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":3,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
    }
    
    func pause() -> Void {
        player.pause()
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":2,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
    }
    
    func seekTo(seek:Int) -> Void {
        player.seek(to: CMTime(seconds: Double(seek/1000), preferredTimescale: 600),toleranceBefore:CMTime.zero ,toleranceAfter: CMTime.zero)
    }
    
    func skipToPrevious() -> Void {
        self.pause()
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":9,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
        MusicPlayDataService.INSTANCE.previous(userTrigger: true)
        initPlay()
    }
    
    func skipToNext() -> Void {
        self.pause()
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":getBufferTime(),"state":10,"position":playerItem?.currentTime().toMilliseconds ?? 0 ])
        MusicPlayDataService.INSTANCE.next(userTrigger: true)
        initPlay()
    }
    
    private func onTimeChange(_ time:CMTime) -> Void {
        var totalBuffer:Int = 0
        if let array = playerItem?.loadedTimeRanges{
            let timeRange = array.first?.timeRangeValue
            totalBuffer = timeRange?.toMilliseconds ?? 0
        }
        
        var status:Int
        if isPlayingNow(){
            status = 3
        }else{
            status = 2
        }
        
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":totalBuffer,"state":status,"position":time.toMilliseconds])
    }
    
    private func onPlayEnd(_ notification: Notification) -> Void {
        print("播放完成")
        MusicPlayDataService.INSTANCE.next(userTrigger: false)
        initPlay()
    }
    
    private func initPlay() -> Void {
        guard let music = MusicPlayDataService.INSTANCE.getNowPlayMusic() else{
            return
        }
        
        self.pause()
        
        let meta:[String:Any] = [
            "mediaId":music.musicId,
            "title":music.name,
            "subTitle":music.singer,
            "duration":0,
            "musicUri":music.musicUri,
            "lyricUri":music.lyricUri,
            "coverUri":music.coverUri
        ]
        
        MetadataEvent.INSTANCE.send(meta)
        PlaybackStateEvent.INSTANCE.send(["bufferedPosition":0,"state":8,"position":0])
        
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        playerItem = nil
        
        playerItem = AVPlayerItem(url: URL(string:music.musicUri)!)
        // 监听状态改变
        playerItem!.addObserver(self,forKeyPath: "status", options: [.old, .new], context: nil)
        // 监听缓冲进度改变
        playerItem!.addObserver(self,forKeyPath: "loadedTimeRanges", options: .new, context: nil)
        
        player.replaceCurrentItem(with: playerItem!)
    }
    
    private func isPlayingNow() -> Bool {
        return player.timeControlStatus == AVPlayer.TimeControlStatus.playing
    }
    
    private func isPausedNow() -> Bool {
        return player.timeControlStatus == AVPlayer.TimeControlStatus.paused
    }
    
    
    private func getBufferTime() -> Int {
        guard let timeRange = playerItem?.loadedTimeRanges.first?.timeRangeValue else{
            return 0
        }
        
        return timeRange.toMilliseconds
    }
    
}

extension CMTime {
    var toMilliseconds:Int {
        let result = CMTimeGetSeconds(self) * 1000
        if result.isNaN || result.isInfinite{
            return 0
        }
        return Int(result)
    }
}

extension CMTimeRange {
    var toMilliseconds:Int {
        let startSecondes = CMTimeGetSeconds(self.start)
        let durationSeconds = CMTimeGetSeconds(self.duration)
        return Int((startSecondes + durationSeconds) * 1000)
    }
}
