package top.itning.yunshu_music.service;

import static top.itning.yunshu_music.channel.MusicChannel.musicPlayDataService;
import static top.itning.yunshu_music.service.MusicBrowserService.ACTIONS;

import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.os.PowerManager;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.IOException;
import java.util.Timer;
import java.util.TimerTask;

/**
 * @author itning
 * @since 2021/10/11 10:20
 */
public class MediaPlayerImpl extends MediaSessionCompat.Callback implements MediaPlayer.OnErrorListener, MediaPlayer.OnPreparedListener, MediaPlayer.OnCompletionListener, MediaPlayer.OnBufferingUpdateListener {

    private static final String TAG = "MediaPlayerImpl";
    private final MediaPlayer mediaPlayer;
    private final MusicBrowserService context;
    private final MediaSessionCompat session;
    private PlaybackStateCompat state;
    private boolean playNow = false;
    private final MusicNotificationService musicNotificationService;

    public MediaPlayerImpl(@NonNull MusicBrowserService context, @NonNull MediaSessionCompat session) {
        Log.d(TAG, "MediaPlayerImpl Constructor");
        this.context = context;
        this.session = session;
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK);
        mediaPlayer.setOnErrorListener(this);
        mediaPlayer.setOnPreparedListener(this);
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnBufferingUpdateListener(this);
        Timer timer = new Timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                if (mediaPlayer.isPlaying()) {
                    state = new PlaybackStateCompat.Builder()
                            .setState(PlaybackStateCompat.STATE_PLAYING, mediaPlayer.getCurrentPosition(), 1.0f)
                            .setBufferedPosition(state.getBufferedPosition())
                            .setActions(ACTIONS)
                            .build();
                    session.setPlaybackState(state);
                }
            }
        }, 0, 500);
        musicNotificationService = new MusicNotificationService(session, context);
        musicNotificationService.generateNotification("云舒音乐", null, null, null);
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
        mediaPlayer.start();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PLAYING, mediaPlayer.getCurrentPosition(), 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        Log.i(TAG, "PlaySpeed：" + mediaPlayer.getPlaybackParams().getSpeed());
        musicNotificationService.updateNotification();
    }

    @Override
    public void onPause() {
        Log.d(TAG, "onPause");
        mediaPlayer.pause();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PAUSED, mediaPlayer.getCurrentPosition(), 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicNotificationService.updateNotification();
    }

    @Override
    public void onStop() {
        Log.d(TAG, "onStop");
        mediaPlayer.stop();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
    }

    @Override
    public void onSeekTo(long pos) {
        Log.d(TAG, "onSeekTo " + pos);
        int duration = mediaPlayer.getDuration();
        int msec = pos > duration ? duration : (int) pos;
        mediaPlayer.seekTo(msec);
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
        mediaPlayer.reset();
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
        mediaPlayer.reset();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_SKIPPING_TO_NEXT, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        musicPlayDataService.next();
        initPlay();
    }

    @Override
    public void onPrepared(MediaPlayer mp) {
        Log.d(TAG, "onPrepared " + mp.getDuration());
        setMetaData();
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PAUSED, 0, 1.0f)
                .setActions(ACTIONS)
                .build();
        mediaPlayer.setPlaybackParams(mediaPlayer.getPlaybackParams().setSpeed(1.0f));
        mediaPlayer.pause();
        if (playNow) {
            this.onPlay();
        } else {
            playNow = true;
        }
    }

    @Override
    public void onBufferingUpdate(MediaPlayer mp, int percent) {
        state = new PlaybackStateCompat.Builder()
                .setState(state.getState(), mediaPlayer.getCurrentPosition(), 1.0f)
                .setBufferedPosition(percent)
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
    }

    @Override
    public void onCompletion(MediaPlayer mp) {
        Log.d(TAG, "onCompletion");
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_NONE, mediaPlayer.getCurrentPosition(), 1.0f)
                .setBufferedPosition(state.getBufferedPosition())
                .setActions(ACTIONS)
                .build();
        session.setPlaybackState(state);
        this.onSkipToNext();
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        Log.e(TAG, "onError what " + what + " extra " + extra);
        state = new PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_ERROR, 0, 1.0f)
                .build();
        session.setPlaybackState(state);
        mp.reset();
        return true;
    }

    private void initPlay() {
        setMetaData(0);
        musicNotificationService.updateNotification();
        try {
            mediaPlayer.reset();
            mediaPlayer.setDataSource(context, musicPlayDataService.getNowPlayMusic().getDescription().getMediaUri());
            mediaPlayer.prepareAsync();
            state = new PlaybackStateCompat.Builder()
                    .setState(PlaybackStateCompat.STATE_CONNECTING, 0, 1.0f)
                    .setActions(ACTIONS)
                    .build();
            session.setPlaybackState(state);
        } catch (IOException e) {
            Log.e(TAG, "setDataSource exception", e);
        }
    }

    private void setMetaData() {
        this.setMetaData(mediaPlayer.getDuration());
    }

    private void setMetaData(int duration) {
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
