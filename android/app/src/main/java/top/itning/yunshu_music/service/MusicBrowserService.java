package top.itning.yunshu_music.service;

import android.os.Bundle;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media.MediaBrowserServiceCompat;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import io.flutter.plugin.common.MethodChannel;
import top.itning.yunshu_music.channel.MusicChannel;
import top.itning.yunshu_music.util.MusicUtils;


/**
 * @author itning
 * @since 2021/10/11 9:59
 */
public class MusicBrowserService extends MediaBrowserServiceCompat {
    private static final String TAG = "MusicBrowserService";
    static final long ACTIONS = PlaybackStateCompat.ACTION_STOP | PlaybackStateCompat.ACTION_PAUSE | PlaybackStateCompat.ACTION_PLAY | PlaybackStateCompat.ACTION_REWIND |
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS | PlaybackStateCompat.ACTION_SKIP_TO_NEXT | PlaybackStateCompat.ACTION_FAST_FORWARD | PlaybackStateCompat.ACTION_SET_RATING |
            PlaybackStateCompat.ACTION_SEEK_TO | PlaybackStateCompat.ACTION_PLAY_PAUSE | PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID | PlaybackStateCompat.ACTION_PLAY_FROM_SEARCH |
            PlaybackStateCompat.ACTION_SKIP_TO_QUEUE_ITEM | PlaybackStateCompat.ACTION_PLAY_FROM_URI | PlaybackStateCompat.ACTION_PREPARE |
            PlaybackStateCompat.ACTION_PREPARE_FROM_MEDIA_ID | PlaybackStateCompat.ACTION_PREPARE_FROM_SEARCH | PlaybackStateCompat.ACTION_PREPARE_FROM_URI |
            PlaybackStateCompat.ACTION_SET_REPEAT_MODE | PlaybackStateCompat.ACTION_SET_SHUFFLE_MODE | PlaybackStateCompat.ACTION_SET_CAPTIONING_ENABLED |
            PlaybackStateCompat.ACTION_SET_PLAYBACK_SPEED;
    private List<MediaBrowserCompat.MediaItem> list;

    @Override
    public void onCreate() {
        super.onCreate();
        MediaSessionCompat session = new MediaSessionCompat(this, "YunShuMusicBrowserService");
        PlaybackStateCompat playbackState = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_NONE, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setCallback(new MediaPlayerImpl(this, session));
        session.setPlaybackState(playbackState);
        session.setRepeatMode(PlaybackStateCompat.REPEAT_MODE_ALL);
        session.setActive(true);
        super.setSessionToken(session.getSessionToken());
    }

    @Nullable
    @Override
    public BrowserRoot onGetRoot(@NonNull String clientPackageName, int clientUid, @Nullable Bundle rootHints) {
        Log.d(TAG, "onGetRoot " + clientPackageName);
        return new BrowserRoot("root", null);
    }

    @Override
    public void onLoadChildren(@NonNull String parentId, @NonNull Result<List<MediaBrowserCompat.MediaItem>> result) {
        Log.d(TAG, "onLoadChildren " + parentId);
        result.detach();
        if (list != null) {
            result.sendResult(list);
            return;
        }
        MusicChannel.methodChannel.invokeMethod("getMusicList", null, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object response) {
                if (null == response) {
                    result.sendResult(null);
                    return;
                }
                @SuppressWarnings("unchecked")
                List<Map<String, String>> musicList = (List<Map<String, String>>) response;
                List<MediaBrowserCompat.MediaItem> list = musicList.stream().map(MusicUtils::to).collect(Collectors.toList());
                MusicBrowserService.this.list = list;
                result.sendResult(list);
            }

            @Override
            public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                result.sendResult(null);
            }

            @Override
            public void notImplemented() {
                result.sendResult(null);
            }
        });
    }

}
