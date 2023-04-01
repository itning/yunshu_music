import Foundation

class MusicPlayDataService {
    
    public static let INSTANCE = MusicPlayDataService()
    
    private let NOW_PLAY_MEDIA_ID_KEY = "NOW_PLAY_MEDIA_ID_KEY"
    private let PLAY_MODE_KEY = "PLAY_MODE_KEY"
    private let PLAY_LIST_KEY = "PLAY_LIST_KEY"
    
    private var MUSIC_LIST:[Music] = []
    private var PLAY_LIST:[Music] = []
    private var RANDOM_SET = Set<Music>()
    
    private var nowPlayIndex:Int = -1
    
    private var nowPlayMusic:Music?
    
    private var playMode:MusicPlayMode
    
    private let kv:UserDefaults
    
    init() {
        self.nowPlayIndex = -1
        self.kv = UserDefaults.standard
        if kv.object(forKey: PLAY_MODE_KEY) == nil {
            kv.set(MusicPlayMode.SEQUENCE.rawValue, forKey:PLAY_MODE_KEY)
            self.playMode = MusicPlayMode.SEQUENCE
        } else {
            let mode:String = kv.string(forKey: PLAY_MODE_KEY) ?? MusicPlayMode.SEQUENCE.rawValue
            self.playMode = MusicPlayMode.valueOf(mode)
        }
    }
    
    func getNowPlayIndex() -> Int {
        return nowPlayIndex
    }
    
    func getNowPlayMusic() -> Music? {
        return nowPlayMusic
    }
    
    func getPlayMode() -> MusicPlayMode {
        return playMode
    }
    
    func getPlayList() -> [Music] {
        return PLAY_LIST
    }
    
    func delPlayListByMediaId(mediaId:String) -> Void {
        PLAY_LIST.removeAll(where: { $0.musicId == mediaId })
        
        do{
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(PLAY_LIST.map{ $0.musicId })
            let playListString = String(data: jsonData, encoding: String.Encoding.utf8)
            kv.set(playListString, forKey: PLAY_LIST_KEY)
        }catch let error{
            print("catch error when set play list \(error)")
        }
    }
    
    func clearPlayList() -> Void {
        PLAY_LIST.removeAll()
        nowPlayIndex = -1
        kv.removeObject(forKey: PLAY_LIST_KEY)
    }
    
    func setPlayMode(playMode:MusicPlayMode) -> Void {
        self.playMode = playMode
        kv.set(playMode.rawValue, forKey: PLAY_MODE_KEY)
    }
    
    func addMusic(musicList:[Music]) -> Void {
        MUSIC_LIST.append(contentsOf: musicList)
        
        do{
            let playListString = kv.string(forKey: PLAY_LIST_KEY) ?? "[]"
            let jsonDecoder = JSONDecoder()
            let playListMusicIdList:[String] = try jsonDecoder.decode([String].self, from: playListString.data(using: String.Encoding.utf8)!)
            var playList:[Music] = []
            for mediaId in playListMusicIdList{
                if let i = MUSIC_LIST.first(where: { $0.musicId == mediaId }){
                    playList.append(i)
                }
            }
            PLAY_LIST.append(contentsOf: playList)
            
        }catch let error{
            print("catch error when add music \(error)")
        }
        
        let nowPlayMediaId = kv.string(forKey: NOW_PLAY_MEDIA_ID_KEY)
        if nowPlayMediaId != nil{
            if let i = PLAY_LIST.firstIndex(where: {$0.musicId==nowPlayMediaId}){
                nowPlayIndex = i
                nowPlayMusic = PLAY_LIST[i]
            }
        }
        if -1 == nowPlayIndex{
            self.next(userTrigger: false)
        }
    }
    
    func removeMusic(music:Music) -> Void {
        MUSIC_LIST.removeAll{ $0 == music }
    }
    
    func playFromMediaId(mediaId:String) -> Void {
        nowPlayIndex = -1;
        nowPlayMusic = nil;
        nowPlayMusic = MUSIC_LIST.first{$0.musicId == mediaId}
        if nowPlayMusic == nil{
            return
        }
        let playListIndex:Int? = PLAY_LIST.firstIndex(of: nowPlayMusic!)
        if playListIndex == nil{
            PLAY_LIST.append(nowPlayMusic!)
            nowPlayIndex = PLAY_LIST.endIndex - 1
        }else{
            nowPlayIndex = playListIndex!
        }
        
        do{
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(PLAY_LIST.map{ $0.musicId })
            let playListString = String(data: jsonData, encoding: String.Encoding.utf8)
            kv.set(playListString, forKey: PLAY_LIST_KEY)
            kv.set(nowPlayMusic!.musicId, forKey: NOW_PLAY_MEDIA_ID_KEY)
        }catch let error{
            print("catch error when set play list \(error)")
        }
    }
    
    func previous(userTrigger:Bool) -> Void {
        if nowPlayIndex - 1 < 0{
            switch playMode {
            case .RANDOMLY:
                let randomMusicListIndex = getRandom()
                nowPlayMusic = MUSIC_LIST[randomMusicListIndex]
                PLAY_LIST.removeAll{$0==nowPlayMusic}
                PLAY_LIST.append(nowPlayMusic!)
                nowPlayIndex = 0
            case .SEQUENCE:
                let sequenceMusicListIndex = toSequencePrevious()
                nowPlayMusic = MUSIC_LIST[sequenceMusicListIndex]
                PLAY_LIST.removeAll{$0==nowPlayMusic}
                PLAY_LIST.insert(nowPlayMusic!, at: 0)
                nowPlayIndex = 0;
            case .LOOP:
                if userTrigger{
                    let loopMusicListIndex = toSequencePrevious()
                    nowPlayMusic = MUSIC_LIST[loopMusicListIndex]
                    PLAY_LIST.removeAll{$0==nowPlayMusic}
                    PLAY_LIST.insert(nowPlayMusic!, at: 0)
                    nowPlayIndex = 0;
                }
            }
        }else if userTrigger || playMode != MusicPlayMode.LOOP{
            nowPlayIndex -= 1
            nowPlayMusic = PLAY_LIST[nowPlayIndex]
        }
        
        do{
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(PLAY_LIST.map{ $0.musicId })
            let playListString = String(data: jsonData, encoding: String.Encoding.utf8)
            kv.set(playListString, forKey: PLAY_LIST_KEY)
            kv.set(nowPlayMusic!.musicId, forKey: NOW_PLAY_MEDIA_ID_KEY)
        }catch let error{
            print("catch error when set play list \(error)")
        }
    }
    
    func next(userTrigger:Bool) -> Void {
        if nowPlayIndex+1 >= PLAY_LIST.endIndex{
            switch playMode {
            case .RANDOMLY:
                let randomMusicListIndex = getRandom()
                nowPlayMusic = MUSIC_LIST[randomMusicListIndex]
                PLAY_LIST.removeAll{$0==nowPlayMusic}
                PLAY_LIST.append(nowPlayMusic!)
                nowPlayIndex += 1
            case .SEQUENCE:
                let sequenceMusicListIndex = toSequenceNext()
                nowPlayMusic = MUSIC_LIST[sequenceMusicListIndex]
                PLAY_LIST.removeAll{$0==nowPlayMusic}
                PLAY_LIST.append(nowPlayMusic!)
                nowPlayIndex += 1
            case .LOOP:
                if userTrigger{
                    let loopMusicListIndex = toSequenceNext()
                    nowPlayMusic = MUSIC_LIST[loopMusicListIndex]
                    PLAY_LIST.removeAll{$0==nowPlayMusic}
                    PLAY_LIST.append(nowPlayMusic!)
                    nowPlayIndex += 1
                }
            }
        }
    }
    
    private func getRandom() -> Int {
        var canPlayList:[Music] = MUSIC_LIST.filter{!RANDOM_SET.contains($0)}.filter{!PLAY_LIST.contains($0)}
        if canPlayList.isEmpty{
            RANDOM_SET.removeAll()
            canPlayList = MUSIC_LIST
        }
        let canPlayListIndex:Int = Int.random(in: 0...canPlayList.endIndex)
        let music:Music = canPlayList[canPlayListIndex]
        RANDOM_SET.insert(music)
        return MUSIC_LIST.firstIndex(of: music)!
    }
    
    private func toSequenceNext() -> Int {
        if nowPlayIndex == -1{
            return 0
        }
        let mediaItem:Music = PLAY_LIST[nowPlayIndex]
        let musicListIndex:Int = MUSIC_LIST.firstIndex(of: mediaItem)!
        if musicListIndex+1 >= MUSIC_LIST.endIndex {
            return 0
        }else{
            return musicListIndex + 1
        }
    }
    
    private func toSequencePrevious()->Int{
        if nowPlayIndex == -1{
            return MUSIC_LIST.endIndex - 1
        }
        let mediaItem:Music = PLAY_LIST[nowPlayIndex]
        let musicListIndex:Int = MUSIC_LIST.firstIndex{$0 == mediaItem}!
        if musicListIndex - 1 < 0{
            return MUSIC_LIST.endIndex - 1
        }else{
            return musicListIndex - 1
        }
    }
    
}
