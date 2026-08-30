package top.itning.yunshu_music.service;

import android.app.PendingIntent;
import android.content.Intent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.session.MediaSession;
import androidx.media3.session.MediaSessionService;

import com.tencent.mmkv.MMKV;

import top.itning.yunshu_music.MainActivity;
import top.itning.yunshu_music.util.HttpClient;

/**
 * Media3 MediaSessionService. Owns a single-item ExoPlayer + MediaSession, and drives the custom
 * notification provider (Glide cover art).
 */
@UnstableApi
public class MusicSessionService extends MediaSessionService {

    private MediaSession session;
    private ExoPlayer player;
    private MediaPlayerImpl callback;

    @Override
    public void onCreate() {
        super.onCreate();
        MMKV.initialize(this);
        AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .setUsage(C.USAGE_MEDIA)
                .build();
        player = new ExoPlayer.Builder(this)
                .setWakeMode(C.WAKE_MODE_NETWORK)
                .setAudioAttributes(audioAttributes, true)
                .setHandleAudioBecomingNoisy(true)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(
                        new OkHttpDataSource.Factory(HttpClient.getCallFactory())))
                .build();
        callback = new MediaPlayerImpl(this, player);
        session = new MediaSession.Builder(this, player)
                .setCallback(callback)
                .setSessionActivity(PendingIntent.getActivity(
                        this, 0,
                        new Intent(this, MainActivity.class)
                                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
                        PendingIntent.FLAG_IMMUTABLE))
                .build();
        player.addListener(callback);
        setMediaNotificationProvider(new MusicNotificationProvider(this));
    }

    @Nullable
    @Override
    public MediaSession onGetSession(@NonNull MediaSession.ControllerInfo controllerInfo) {
        return session;
    }

    @Override
    public void onDestroy() {
        if (session != null) {
            session.release();
            session = null;
        }
        if (player != null) {
            player.release();
            player = null;
        }
        super.onDestroy();
    }
}
