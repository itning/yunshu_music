package top.itning.yunshu.music.yunshu_music;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import org.greenrobot.eventbus.EventBus;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static MethodChannel methodChannel;
    private static boolean isPlay = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = new Intent(this, MusicPlayNotificationService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/playStatus");
        methodChannel.setMethodCallHandler((call, result) -> {
            if ("setNowPlayMusicInfo".equals(call.method)) {
                try {
                    String name = call.argument("name");
                    String singer = call.argument("singer");
                    Boolean play = call.argument("play");
                    String cover = call.argument("cover");
                    Log.d(TAG, "receive setNowPlayMusicInfo params play:" + play + " name:" + name + " singer:" + singer + " cover:" + (cover == null ? null : cover.length()));
                    MusicPlayNotificationService.MessageEvent messageEvent = new MusicPlayNotificationService.MessageEvent();
                    messageEvent.setCoverBase64(cover);
                    messageEvent.setName(name);
                    messageEvent.setPlay(play);
                    messageEvent.setSinger(singer);
                    EventBus.getDefault().post(messageEvent);
                    if (null != play) {
                        isPlay = play;
                    }
                    result.success(null);
                } catch (Exception e) {
                    Log.e(TAG, "receive invoke error", e);
                    result.error("-1", e.getMessage(), null);
                }
            } else {
                result.notImplemented();
            }
        });
        super.configureFlutterEngine(flutterEngine);
    }
    
    public static class MusicControllerReceiver extends BroadcastReceiver {

        public static final String TAG = "MusicControllerReceiver";

        @Override
        public void onReceive(Context context, Intent intent) {
            Log.i(TAG, MusicPlayNotificationService.PlayStatus.valueOf(intent.getAction()).toString());
            switch (MusicPlayNotificationService.PlayStatus.valueOf(intent.getAction())) {
                case PREVIOUS:
                    methodChannel.invokeMethod("toPrevious", null);
                    break;
                case PLAY_PAUSE:
                    methodChannel.invokeMethod("changePlay", !isPlay);
                    break;
                case NEXT:
                    methodChannel.invokeMethod("toNext", null);
                    break;
            }
        }
    }
}
