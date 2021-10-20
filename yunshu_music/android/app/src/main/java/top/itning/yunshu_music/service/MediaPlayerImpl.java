package top.itning.yunshu_music.service;

import static top.itning.yunshu_music.channel.MusicChannel.musicPlayDataService;
import static top.itning.yunshu_music.service.MusicBrowserService.ACTIONS;

import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.PlaybackException;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.audio.AudioAttributes;

/**
 * @author itning
 * @since 2021/10/11 10:20
 */
public class MediaPlayerImpl extends MediaSessionCompat.Callback implements Player.Listener {

    private static final String TAG = "MediaPlayerImpl";
    private final MusicBrowserService context;
    private final MediaSessionCompat session;
    private final MusicNotificationService musicNotificationService;
    private PlaybackStateCompat state;
    private boolean playNow = false;
    private final SimpleExoPlayer player;
    private final Handler updatePositionHandler;
    private final Runnable updatePositionRunnable;

    public MediaPlayerImpl(@NonNull MusicBrowserService context, @NonNull MediaSessionCompat session) {
        Log.d(TAG, "MediaPlayerImpl Constructor");
        this.context = context;
        this.session = session;
        AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setContentType(C.CONTENT_TYPE_MUSIC)
                //.setFlags()
                .setAllowedCapturePolicy(C.ALLOW_CAPTURE_BY_ALL)
                .setUsage(C.USAGE_MEDIA)
                .build();
        player = new SimpleExoPlayer.Builder(context)
                .setWakeMode(C.WAKE_MODE_NETWORK)
                .setAudioAttributes(audioAttributes, true)
                .setHandleAudioBecomingNoisy(true)
                .build();
        player.addListener(this);
        updatePositionHandler = new Handler(player.getApplicationLooper());
        updatePositionRunnable = this::updatePosition;
        musicNotificationService = new MusicNotificationService(session, context);
        musicNotificationService.generateNotification("云舒音乐", null, null, null);
    }

    private void updatePosition() {
        updatePositionHandler.removeCallbacks(updatePositionRunnable);
        if (player.isPlaying()) {
            state = new PlaybackStateCompat.Builder()
                    .setState(PlaybackStateCompat.STATE_PLAYING, player.getCurrentPosition(), 1.0f)
                    .setBufferedPosition(player.getBufferedPosition())
                    .setActions(ACTIONS)
                    .build();
            session.setPlaybackState(state);
        } else if (null != state) {
            state = new PlaybackStateCompat.Builder()
                    .setState(state.getState(), player.getCurrentPosition(), 1.0f)
                    .setBufferedPosition(player.getBufferedPosition())
                    .setActions(ACTIONS)
                    .build();
            session.setPlaybackState(state);
        }
        int playbackState = player.getPlaybackState();
        if (playbackState != Player.STATE_IDLE && playbackState != Player.STATE_ENDED) {
            updatePositionHandler.postDelayed(updatePositionRunnable, 500);
        }
    }

    @Override
    public void onPlayFromMediaId(String mediaId, Bundle extras) {
        Log.d(TAG, "onPlayFromMediaId " + mediaId);
        musicPlayDataService.playFromMediaId(mediaId);
        if (musicPlayDataService.getNowPlayMusic() == null) {
            return;
        }
        initPlay();
    }

    @Override
    public void onPlay() {
        Log.d(TAG, "onPlay");
        player.play();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PLAYING, player.getCurrentPosition(), 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicNotificationService.updateNotification();
    }

    @Override
    public void onPause() {
        Log.d(TAG, "onPause");
        player.pause();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PAUSED, player.getCurrentPosition(), 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicNotificationService.updateNotification();
    }

    @Override
    public void onStop() {
        Log.d(TAG, "onStop");
        player.stop();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
    }

    @Override
    public void onSeekTo(long pos) {
        Log.d(TAG, "onSeekTo " + pos);
        long duration = player.getDuration();
        long msec = Math.min(pos, duration);
        player.seekTo(msec);
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PLAYING, msec, 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
    }

    @Override
    public void onSkipToPrevious() {
        Log.d(TAG, "onSkipToPrevious");
        player.stop();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_SKIPPING_TO_PREVIOUS, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicPlayDataService.previous();
        initPlay();
    }

    @Override
    public void onSkipToNext() {
        Log.d(TAG, "onSkipToNext");
        player.stop();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_SKIPPING_TO_NEXT, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicPlayDataService.next();
        initPlay();
    }

    @Override
    public void onPlaybackStateChanged(int playbackState) {
        updatePosition();
        switch (playbackState) {
            case Player.STATE_IDLE:
                Log.d(TAG, "onPlaybackStateChanged STATE_IDLE");
                break;
            case Player.STATE_BUFFERING:
                Log.d(TAG, "onPlaybackStateChanged STATE_BUFFERING");
                break;
            case Player.STATE_READY:
                Log.d(TAG, "onPlaybackStateChanged STATE_READY");
                setMetaData();
                state = new PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PAUSED, 0, 1.0f)
                        .setActions(ACTIONS)
                        .build();
                session.setPlaybackState(state);
                if (playNow) {
                    this.onPlay();
                } else {
                    playNow = true;
                }
                break;
            case Player.STATE_ENDED:
                Log.d(TAG, "onPlaybackStateChanged STATE_ENDED");
                state = new PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_NONE, player.getCurrentPosition(), 1.0f)
                        .setBufferedPosition(state.getBufferedPosition())
                        .setActions(ACTIONS)
                        .build();
                session.setPlaybackState(state);
                this.onSkipToNext();
                break;
        }
    }

    @Override
    public void onPlayerError(@NonNull PlaybackException error) {
        Log.w(TAG, "onPlayerError ", error);
        Toast.makeText(context,  error.getErrorCodeName(), Toast.LENGTH_LONG).show();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_ERROR, 0, 1.0f)
                .build();
        session.setPlaybackState(state);
    }

    private void initPlay() {
        setMetaData(0);
        musicNotificationService.updateNotification();

        Uri mediaUri = musicPlayDataService.getNowPlayMusic().getDescription().getMediaUri();
        if (null == mediaUri) {
            return;
        }

        MediaItem mediaItem = MediaItem.fromUri(mediaUri);
        player.setMediaItem(mediaItem);
        player.prepare();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_CONNECTING, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
    }

    private void setMetaData() {
        this.setMetaData(player.getDuration());
    }

    private void setMetaData(long duration) {
        Uri iconUri = musicPlayDataService.getNowPlayMusic().getDescription().getIconUri();
        String artUri = iconUri == null ? null : iconUri.toString();
        session.setMetadata(new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, musicPlayDataService.getNowPlayMusic().getMediaId())
                .putText(MediaMetadataCompat.METADATA_KEY_TITLE, musicPlayDataService.getNowPlayMusic().getDescription().getTitle())
                .putText(MediaMetadataCompat.METADATA_KEY_ARTIST, musicPlayDataService.getNowPlayMusic().getDescription().getSubtitle())
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                .putString("android.media.metadata.LYRIC_URI", musicPlayDataService.getNowPlayLyricUri())
                .putText(MediaMetadataCompat.METADATA_KEY_ART_URI, artUri)
                .build());
    }
}
