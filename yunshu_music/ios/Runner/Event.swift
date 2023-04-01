import Foundation
import Flutter

class PlaybackStateEvent : NSObject , FlutterStreamHandler {
    public static let INSTANCE = PlaybackStateEvent()
    
    private var events:FlutterEventSink?
    
    func send(_ any:Any) -> Void{
        self.events?(any)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("PlaybackStateEvent on listen")
        self.events = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("PlaybackStateEvent on cancel")
        return nil
    }
}

class MetadataEvent : NSObject , FlutterStreamHandler {
    public static let INSTANCE = MetadataEvent()
    
    private var events:FlutterEventSink?
    
    func send(_ any:Any) -> Void{
        self.events?(any)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("MetadataEvent on listen")
        self.events = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("MetadataEvent on cancel")
        return nil
    }
}
