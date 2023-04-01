import Foundation

struct Music: Hashable{
    var musicId:String
    var name:String
    var singer:String
    var lyricId:String
    var type:Int
    var musicUri:String
    var lyricUri:String
    var coverUri:String
    
    
    static func == (left:Music,right:Music)->Bool{
        return left.musicId == right.musicId
    }
}
