package top.itning.yunshu_music;

import static top.itning.yunshu_music.channel.MusicChannel.methodChannel;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.ComponentName;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.WindowManager;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;
import androidx.media3.common.Player;
import androidx.media3.session.MediaController;
import androidx.media3.session.SessionCommand;
import androidx.media3.session.SessionToken;

import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;
import com.tencent.mmkv.MMKV;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import top.itning.yunshu_music.channel.MusicChannel;
import top.itning.yunshu_music.service.MediaPlayerImpl;
import top.itning.yunshu_music.service.MusicPlayDataService;
import top.itning.yunshu_music.service.MusicPlayMode;
import top.itning.yunshu_music.service.MusicSessionService;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final int REQUEST_NOTIFICATION_PERMISSION = 1001;
    private MediaController controller;
    private final PlaybackStateEvent playbackStateEvent = new PlaybackStateEvent();
    private final MetadataEvent metadataEvent = new MetadataEvent();
    private final Handler uiHandler = new Handler(Looper.getMainLooper());
    private final Runnable positionRunnable = new Runnable() {
        @Override
        public void run() {
            MediaController c = controller;
            if (c == null) {
                return;
            }
            pushPlaybackState(c);
            int s = c.getPlaybackState();
            if (s != Player.STATE_IDLE && s != Player.STATE_ENDED) {
                uiHandler.postDelayed(this, 500);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        MMKV.initialize(this);
        super.onCreate(savedInstanceState);
        NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_LOW);
        NotificationManager notificationManager = (NotificationManager) this.getSystemService(NOTIFICATION_SERVICE);
        notificationManager.createNotificationChannel(channel);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/method_channel");
        EventChannel playbackStateEventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/playback_state_event_channel");
        EventChannel metadataEventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "yunshu.music/metadata_event_channel");
        playbackStateEventChannel.setStreamHandler(playbackStateEvent);
        metadataEventChannel.setStreamHandler(metadataEvent);

        connectController();

        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "init":
                    methodChannel.invokeMethod("getAuthorizationData", null, new MethodChannel.Result() {
                        @Override
                        public void success(@Nullable Object response) {
                            if (null == response) {
                                return;
                            }
                            @SuppressWarnings("unchecked")
                            Map<String, Object> data = (Map<String, Object>) response;
                            MusicChannel.authorizationData = data;
                        }

                        @Override
                        public void error(@NonNull String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                            Log.e(TAG, "getAuthorizationData error " + errorCode + " " + errorMessage + " " + errorDetails);
                        }

                        @Override
                        public void notImplemented() {
                        }
                    });
                    result.success(null);
                    break;
                case "playFromId":
                    if (!call.hasArgument("id")) {
                        result.error("-1", null, null);
                        break;
                    }
                    sendCustomCommand(MediaPlayerImpl.ACTION_PLAY_FROM_ID, call.argument("id"));
                    result.success(null);
                    break;
                case "play":
                    withController(MediaController::play, result);
                    break;
                case "pause":
                    withController(MediaController::pause, result);
                    break;
                case "seekTo":
                    if (!call.hasArgument("position")) {
                        result.error("-1", null, null);
                        break;
                    }
                    @SuppressWarnings("ConstantConditions")
                    int position = call.argument("position");
                    withController(c -> c.seekTo(position), result);
                    break;
                case "skipToPrevious":
                    sendCustomCommand(MediaPlayerImpl.ACTION_SKIP_PREVIOUS, null);
                    result.success(null);
                    break;
                case "skipToNext":
                    sendCustomCommand(MediaPlayerImpl.ACTION_SKIP_NEXT, null);
                    result.success(null);
                    break;
                case "setPlayMode":
                    if (!call.hasArgument("mode")) {
                        result.error("-1", null, null);
                        break;
                    }
                    try {
                        String mode = call.argument("mode");
                        MusicChannel.musicPlayDataService.setPlayMode(MusicPlayMode.valueOf(mode.toUpperCase()));
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
                                map.put("mediaId", item.mediaId);
                                map.put("title", MusicChannel.musicPlayDataService.getTitle(item) == null
                                        ? null : MusicChannel.musicPlayDataService.getTitle(item).toString());
                                map.put("subTitle", MusicChannel.musicPlayDataService.getSinger(item) == null
                                        ? null : MusicChannel.musicPlayDataService.getSinger(item).toString());
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
                        MusicChannel.musicPlayDataService.delPlayListByMediaId(call.argument("mediaId"));
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
                case "setKeepScreenOn":
                    if (!call.hasArgument("on")) {
                        result.error("-1", null, null);
                        break;
                    }
                    boolean keepScreenOn = Boolean.TRUE.equals(call.argument("on"));
                    runOnUiThread(() -> {
                        if (keepScreenOn) {
                            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                        } else {
                            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                        }
                    });
                    result.success(null);
                    break;
                case "requestNotificationPermission":
                    requestNotificationPermission();
                    result.success(null);
                    break;
                case "minimizeApp":
                    moveTaskToBack(true);
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        });
        super.configureFlutterEngine(flutterEngine);
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return;
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return;
        }
        requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATION_PERMISSION);
    }

    private void connectController() {
        SessionToken token = new SessionToken(this, new ComponentName(this, MusicSessionService.class));
        ListenableFuture<MediaController> future = new MediaController.Builder(this, token).buildAsync();
        future.addListener(() -> {
            MediaController c;
            try {
                c = Futures.getDone(future);
            } catch (Exception e) {
                Log.e(TAG, "controller connect failed", e);
                return;
            }
            controller = c;
            c.addListener(new Player.Listener() {
                @Override
                public void onPlaybackStateChanged(@androidx.media3.common.Player.State int playbackState) {
                    uiHandler.removeCallbacks(positionRunnable);
                    pushPlaybackState(c);
                    if (playbackState == Player.STATE_READY) {
                        pushMetadata(c);
                    }
                    int s = c.getPlaybackState();
                    if (s != Player.STATE_IDLE && s != Player.STATE_ENDED) {
                        uiHandler.postDelayed(positionRunnable, 500);
                    }
                }

                @Override
                public void onMediaMetadataChanged(MediaMetadata metadata) {
                    pushMetadata(c);
                }
            });
            onControllerConnected();
        }, getMainExecutor());
    }

    private int mapState(MediaController c) {
        int s = c.getPlaybackState();
        if (s == Player.STATE_BUFFERING) {
            return 8; // PlaybackStateCompat.STATE_BUFFERING
        } else if (c.getPlayWhenReady() && s == Player.STATE_READY) {
            return 3; // PlaybackStateCompat.STATE_PLAYING
        } else if (s == Player.STATE_ENDED) {
            return 2; // PlaybackStateCompat.STATE_PAUSED
        } else if (s == Player.STATE_IDLE) {
            return 1; // PlaybackStateCompat.STATE_STOPPED
        } else {
            return 2; // PlaybackStateCompat.STATE_PAUSED
        }
    }

    private void pushPlaybackState(MediaController c) {
        Map<String, Object> map = new HashMap<>((int) (3 / 0.75F + 1.0F));
        map.put("bufferedPosition", Math.max(0, c.getBufferedPosition()));
        map.put("state", mapState(c));
        map.put("position", Math.max(0, c.getCurrentPosition()));
        playbackStateEvent.send(map);
    }

    private void pushMetadata(MediaController c) {
        MediaMetadata metadata = c.getMediaMetadata();
        MediaItem current = c.getCurrentMediaItem();
        Bundle extras = metadata.extras;
        long duration = c.getDuration();
        if (duration < 0) {
            duration = metadata.durationMs == null ? 0L : metadata.durationMs;
        }
        int durationMs = (int) Math.max(0, duration);
        Map<String, Object> map = new HashMap<>((int) (7 / 0.75F + 1.0F));
        map.put("mediaId", current == null ? "" : current.mediaId);
        map.put("title", metadata.title == null ? "" : metadata.title.toString());
        map.put("subTitle", metadata.artist == null ? "" : metadata.artist.toString());
        map.put("duration", durationMs);
        map.put("musicUri", current == null || current.localConfiguration == null || current.localConfiguration.uri == null
                ? "" : current.localConfiguration.uri.toString());
        map.put("lyricUri", extras == null || extras.getString("lyricUri") == null ? "" : extras.getString("lyricUri"));
        map.put("coverUri", metadata.artworkUri == null ? "" : metadata.artworkUri.toString());
        metadataEvent.send(map);
    }

    private void onControllerConnected() {
        methodChannel.invokeMethod("getMusicList", null, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object response) {
                if (null == response) {
                    return;
                }
                @SuppressWarnings("unchecked")
                List<Map<String, String>> musicList = (List<Map<String, String>>) response;
                List<MediaItem> items = musicList.stream()
                        .map(m -> MusicPlayDataService.buildMediaItem(
                                m.get("musicId"), m.get("musicUri"), m.get("name"), m.get("singer"),
                                m.get("coverUri"), m.get("lyricUri")))
                        .collect(Collectors.toList());
                MusicChannel.musicPlayDataService.addMusic(items);
                MediaItem now = MusicChannel.musicPlayDataService.getNowPlayMusic();
                if (now != null) {
                    sendCustomCommand(MediaPlayerImpl.ACTION_PLAY_FROM_ID, now.mediaId);
                }
            }

            @Override
            public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
            }

            @Override
            public void notImplemented() {
            }
        });
    }

    private void sendCustomCommand(String action, String id) {
        SessionCommand command = new SessionCommand(action, new Bundle());
        Bundle args = new Bundle();
        if (id != null) {
            args.putString("id", id);
        }
        if (controller == null) {
            Log.w(TAG, "controller not ready, drop " + action);
            return;
        }
        controller.sendCustomCommand(command, args);
    }

    private void withController(Consumer<MediaController> action, MethodChannel.Result result) {
        if (controller == null) {
            result.error("-1", "controller not ready", null);
            return;
        }
        try {
            action.accept(controller);
            result.success(null);
        } catch (Exception e) {
            Log.e(TAG, "controller error", e);
            result.error("-1", null, null);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        setVolumeControlStream(AudioManager.STREAM_MUSIC);
    }

    @Override
    protected void onDestroy() {
        uiHandler.removeCallbacks(positionRunnable);
        MediaController c = controller;
        controller = null;
        if (c != null) {
            c.release();
        }
        super.onDestroy();
    }

    private class PlaybackStateEvent implements EventChannel.StreamHandler {
        private EventChannel.EventSink events;

        public void send(Object o) {
            if (events != null) {
                events.success(o);
            }
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
            if (events != null) {
                events.success(o);
            }
        }

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            this.events = events;
        }

        @Override
        public void onCancel(Object arguments) {
        }
    }
}
