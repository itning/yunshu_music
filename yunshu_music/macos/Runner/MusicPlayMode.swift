import Foundation

enum MusicPlayMode:String {
    case SEQUENCE,RANDOMLY,LOOP
    
    static func getNext(_ nowMode:MusicPlayMode)->MusicPlayMode{
        switch nowMode {
        case .SEQUENCE:
            return MusicPlayMode.RANDOMLY
        case .RANDOMLY:
            return MusicPlayMode.LOOP
        case .LOOP:
            return MusicPlayMode.SEQUENCE
        }
    }
    
    static func valueOf(_ value:String)->MusicPlayMode{
        if value == MusicPlayMode.LOOP.rawValue{
            return .LOOP
        }
        if value == MusicPlayMode.SEQUENCE.rawValue{
            return .SEQUENCE
        }
        if value == MusicPlayMode.RANDOMLY.rawValue{
            return .RANDOMLY
        }
        return .SEQUENCE
    }
}
