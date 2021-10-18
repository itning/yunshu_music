package top.itning.yunshu_music.service;

import static top.itning.yunshu_music.channel.MusicChannel.musicPlayDataService;
import static top.itning.yunshu_music.service.MusicBrowserService.ACTIONS;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
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
public class MediaPlayerImpl extends MediaSessionCompat.Callback implements MediaPlayer.OnErrorListener, MediaPlayer.OnPreparedListener, MediaPlayer.OnCompletionListener, MediaPlayer.OnBufferingUpdateListener, AudioManager.OnAudioFocusChangeListener {

    private static final String TAG = "MediaPlayerImpl";
    private final MediaPlayer mediaPlayer;
    private final MusicBrowserService context;
    private final MediaSessionCompat session;
    private final MusicNotificationService musicNotificationService;
    private final IntentFilter intentFilter;
    private final BecomingNoisyReceiver noisyAudioStreamReceiver;
    private PlaybackStateCompat state;
    private boolean playNow = false;
    private final AudioFocusRequest focusRequest;
    private final AudioManager audioManager;

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
        noisyAudioStreamReceiver = new BecomingNoisyReceiver();
        intentFilter = new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY);
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

        // 在 Android 8.0（API 级别 26）中，
        // 当其他应用使用 AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK 请求焦点时，
        // 系统可以在不调用应用的 onAudioFocusChange() 回调的情况下降低和恢复音量。
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();
        focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener(this)
                .build();
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
        context.registerReceiver(noisyAudioStreamReceiver, intentFilter);
        int res = audioManager.requestAudioFocus(focusRequest);
        if (res == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.d(TAG, "request audio focus：AUDIOFOCUS_REQUEST_GRANTED");
        } else if (res == AudioManager.AUDIOFOCUS_REQUEST_FAILED) {
            Log.w(TAG, "request audio focus：AUDIOFOCUS_REQUEST_FAILED");
            return;
        } else if (res == AudioManager.AUDIOFOCUS_REQUEST_DELAYED) {
            Log.i(TAG, "request audio focus：AUDIOFOCUS_REQUEST_DELAYED");
            return;
        }
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
        context.unregisterReceiver(noisyAudioStreamReceiver);
        mediaPlayer.pause();
        int resp = audioManager.abandonAudioFocusRequest(focusRequest);
        if (resp == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.d(TAG, "on pause abandon audio focus request granted");
        } else if (resp == AudioManager.AUDIOFOCUS_REQUEST_FAILED) {
            Log.w(TAG, "on pause abandon audio focus request failed");
        }
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
        context.unregisterReceiver(noisyAudioStreamReceiver);
        mediaPlayer.stop();
        int resp = audioManager.abandonAudioFocusRequest(focusRequest);
        if (resp == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.d(TAG, "on stop abandon audio focus request granted");
        } else if (resp == AudioManager.AUDIOFOCUS_REQUEST_FAILED) {
            Log.w(TAG, "on stop abandon audio focus request failed");
        }
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

    @Override
    public void onAudioFocusChange(int focusChange) {
        switch (focusChange) {
            // 短暂性丢失焦点，当其他应用申请AUDIOFOCUS_GAIN_TRANSIENT或AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE时，会触发此回调事件
            // 例如播放短视频，拨打电话等。
            // 通常需要暂停音乐播放
            case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
                Log.d(TAG, "onAudioFocusChange AUDIOFOCUS_LOSS_TRANSIENT");
                context.unregisterReceiver(noisyAudioStreamReceiver);
                mediaPlayer.pause();
                state = new PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PAUSED, mediaPlayer.getCurrentPosition(), 1.0f)
                        .setBufferedPosition(state.getBufferedPosition())
                        .setActions(ACTIONS)
                        .build();
                session.setPlaybackState(state);
                musicNotificationService.updateNotification();
                break;
            // 当其他应用申请焦点之后又释放焦点会触发此回调
            // 可重新播放音乐
            case AudioManager.AUDIOFOCUS_GAIN:
                Log.d(TAG, "onAudioFocusChange AUDIOFOCUS_GAIN");
                context.registerReceiver(noisyAudioStreamReceiver, intentFilter);
                mediaPlayer.start();
                state = new PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PLAYING, mediaPlayer.getCurrentPosition(), 1.0f)
                        .setBufferedPosition(state.getBufferedPosition())
                        .setActions(ACTIONS)
                        .build();
                session.setPlaybackState(state);
                Log.i(TAG, "PlaySpeed：" + mediaPlayer.getPlaybackParams().getSpeed());
                musicNotificationService.updateNotification();
                break;
            // 长时间丢失焦点,当其他应用申请的焦点为AUDIOFOCUS_GAIN时，会触发此回调事件
            // 例如播放QQ音乐，网易云音乐等
            // 此时应当暂停音频并释放音频相关的资源。
            case AudioManager.AUDIOFOCUS_LOSS:
                Log.d(TAG, "onAudioFocusChange AUDIOFOCUS_LOSS");
                context.unregisterReceiver(noisyAudioStreamReceiver);
                mediaPlayer.pause();
                state = new PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PAUSED, mediaPlayer.getCurrentPosition(), 1.0f)
                        .setBufferedPosition(state.getBufferedPosition())
                        .setActions(ACTIONS)
                        .build();
                session.setPlaybackState(state);
                musicNotificationService.updateNotification();
                break;
            // 短暂性丢失焦点并作降音处理，当其他应用申请AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK时，会触发此回调事件
            // 通常需要降低音量
            case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
                Log.d(TAG, "onAudioFocusChange AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK");
                break;
        }
    }

    private class BecomingNoisyReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY.equals(intent.getAction())) {
                Log.d(TAG, "receive audio becoming noisy");
                if (mediaPlayer.isPlaying()) {
                    MediaPlayerImpl.this.onPause();
                }
            }
        }
    }
}
