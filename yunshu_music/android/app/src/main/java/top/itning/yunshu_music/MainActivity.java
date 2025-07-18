package top.itning.yunshu_music;

import static top.itning.yunshu_music.channel.MusicChannel.methodChannel;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.ComponentName;
import android.content.Context;
import android.media.AudioManager;
import android.os.Bundle;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaDescriptionCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.mmkv.MMKV;

import java.text.MessageFormat;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import top.itning.yunshu_music.channel.MusicChannel;
import top.itning.yunshu_music.service.MusicBrowserService;
import top.itning.yunshu_music.service.MusicPlayMode;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private MediaBrowserCompat browser;
    private MediaControllerCompat controller;
    private final SubscriptionCall subscriptionCall = new SubscriptionCall();
    private final PlaybackStateEvent playbackStateEvent = new PlaybackStateEvent();
    private final MetadataEvent metadataEvent = new MetadataEvent();
    private final PlayCallback playCallback = new PlayCallback();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "onCreate" + this.toString());
        MMKV.initialize(this);
        super.onCreate(savedInstanceState);
        NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_LOW);
        NotificationManager notificationManager = (NotificationManager) this.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.createNotificationChannel(channel);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        Log.d(TAG, "configureFlutterEngine" + this.toString());
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/method_channel");
        EventChannel playbackStateEventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/playback_state_event_channel");
        EventChannel metadataEventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/metadata_event_channel");
        playbackStateEventChannel.setStreamHandler(playbackStateEvent);
        metadataEventChannel.setStreamHandler(metadataEvent);
        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "init":
                    methodChannel.invokeMethod("getAuthorizationData", null, new MethodChannel.Result() {
                        @Override
                        public void success(@Nullable Object response) {
                            if (null == response) {
                                return;
                            }
                            //noinspection unchecked
                            MusicChannel.authorizationData = (Map<String, Object>) response;
                        }

                        @Override
                        public void error(@NonNull String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                            Log.e(TAG, MessageFormat.format("getAuthorizationData error {0} {1} {2}", errorCode, errorMessage, errorDetails));
                        }

                        @Override
                        public void notImplemented() {
                        }
                    });
                    try {
                        if (!browser.isConnected()) {
                            browser.connect();
                        }
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "connect error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "playFromId":
                    if (!call.hasArgument("id")) {
                        result.error("-1", null, null);
                        break;
                    }
                    String id = call.argument("id");
                    try {
                        controller.getTransportControls().playFromMediaId(id, null);
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "playFromId error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "play":
                    try {
                        controller.getTransportControls().play();
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "play error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "pause":
                    try {
                        controller.getTransportControls().pause();
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "pause error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "seekTo":
                    if (!call.hasArgument("position")) {
                        result.error("-1", null, null);
                        break;
                    }
                    @SuppressWarnings("ConstantConditions")
                    int position = call.argument("position");
                    try {
                        controller.getTransportControls().seekTo(position);
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "seekTo error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "skipToPrevious":
                    try {
                        controller.getTransportControls().skipToPrevious();
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "skipToPrevious error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "skipToNext":
                    try {
                        controller.getTransportControls().skipToNext();
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "skipToNext error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "setPlayMode":
                    if (!call.hasArgument("mode")) {
                        result.error("-1", null, null);
                        break;
                    }
                    try {
                        String mode = call.argument("mode");
                        @SuppressWarnings("ConstantConditions")
                        MusicPlayMode musicPlayMode = MusicPlayMode.valueOf(mode.toUpperCase());
                        MusicChannel.musicPlayDataService.setPlayMode(musicPlayMode);
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "playMode error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "getPlayMode":
                    result.success(MusicChannel.musicPlayDataService.getPlayMode().name().toLowerCase());
                    break;
                case "getPlayList":
                    result.success(MusicChannel.musicPlayDataService.getPlayList().stream()
                            .map(item -> {
                                Map<String, String> map = new HashMap<>((int) (3 / 0.75F + 1.0F));
                                map.put("mediaId", item.getMediaId());
                                map.put("title", item.getDescription().getTitle() == null ? null : item.getDescription().getTitle().toString());
                                map.put("subTitle", item.getDescription().getSubtitle() == null ? null : item.getDescription().getSubtitle().toString());
                                return map;
                            })
                            .collect(Collectors.toList()));
                    break;
                case "delPlayListByMediaId":
                    if (!call.hasArgument("mediaId")) {
                        result.error("-1", null, null);
                        break;
                    }
                    try {
                        String mediaId = call.argument("mediaId");
                        MusicChannel.musicPlayDataService.delPlayListByMediaId(mediaId);
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "playMode error", e);
                        result.error("-1", null, null);
                    }
                    break;
                case "clearPlayList":
                    try {
                        MusicChannel.musicPlayDataService.clearPlayList();
                        result.success(null);
                    } catch (Exception e) {
                        Log.e(TAG, "clearPlayList error", e);
                        result.error("-1", null, null);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
        browser = new MediaBrowserCompat(this, new ComponentName(this, MusicBrowserService.class), new MediaBrowserCompat.ConnectionCallback() {

            @Override
            public void onConnected() {
                Log.d(TAG, "MediaBrowserCompat onConnected");
                if (browser.isConnected()) {
                    controller = new MediaControllerCompat(getApplicationContext(), browser.getSessionToken());
                    controller.registerCallback(playCallback);
                    browser.subscribe(browser.getRoot(), subscriptionCall);
                }
            }

            @Override
            public void onConnectionFailed() {
                Log.e(TAG, "onConnectionFailed");
                Toast.makeText(MainActivity.this, "连接失败", Toast.LENGTH_LONG).show();
            }
        }, null);
        super.configureFlutterEngine(flutterEngine);
    }

    @Override
    protected void onResume() {
        Log.d(TAG, "onResume");
        super.onResume();
        setVolumeControlStream(AudioManager.STREAM_MUSIC);
    }

    @Override
    protected void onDestroy() {
        Log.d(TAG, "onDestroy");
        super.onDestroy();
        browser.disconnect();
    }

    private class PlaybackStateEvent implements EventChannel.StreamHandler {

        private EventChannel.EventSink events;

        public void send(Object o) {
            events.success(o);
        }

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            this.events = events;
        }

        @Override
        public void onCancel(Object arguments) {

        }
    }

    private class MetadataEvent implements EventChannel.StreamHandler {

        private EventChannel.EventSink events;

        public void send(Object o) {
            events.success(o);
        }

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            this.events = events;
        }

        @Override
        public void onCancel(Object arguments) {

        }
    }

    private class PlayCallback extends MediaControllerCompat.Callback {

        @Override
        public void onPlaybackStateChanged(PlaybackStateCompat state) {
            Map<String, Object> map = new HashMap<>((int) (3 / 0.75F + 1.0F));
            map.put("bufferedPosition", state.getBufferedPosition());
            map.put("state", state.getState());
            map.put("position", state.getPosition());
            playbackStateEvent.send(map);
        }

        @Override
        public void onMetadataChanged(MediaMetadataCompat metadata) {
            MediaDescriptionCompat description = metadata.getDescription();
            Map<String, Object> map = new HashMap<>((int) (7 / 0.75F + 1.0F));
            map.put("mediaId", description.getMediaId());
            map.put("title", description.getTitle());
            map.put("subTitle", description.getSubtitle());
            map.put("duration", metadata.getLong(MediaMetadataCompat.METADATA_KEY_DURATION));
            map.put("musicUri", description.getMediaUri() == null ? "" : description.getMediaUri().toString());
            map.put("lyricUri", metadata.getBundle().getString("lyricUri"));
            map.put("coverUri", description.getIconUri() == null ? "" : description.getIconUri().toString());
            metadataEvent.send(map);
        }
    }

    private class SubscriptionCall extends MediaBrowserCompat.SubscriptionCallback {
        @Override
        public void onChildrenLoaded(@NonNull String parentId, @NonNull List<MediaBrowserCompat.MediaItem> children) {
            Log.d(TAG, "onChildrenLoaded " + parentId + " " + MainActivity.this.getPackageName() + " " + children.size());
            MusicChannel.musicPlayDataService.addMusic(children);
            controller.getTransportControls().playFromMediaId(MusicChannel.musicPlayDataService.getNowPlayMusic().getMediaId(), null);
        }
    }
}
