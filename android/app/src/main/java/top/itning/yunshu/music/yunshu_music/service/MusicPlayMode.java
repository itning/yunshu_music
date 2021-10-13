package top.itning.yunshu.music.yunshu_music.service;

import android.support.v4.media.session.PlaybackStateCompat;

/**
 * @author itning
 * @since 2021/10/12 15:05
 */
public enum MusicPlayMode {
    SEQUENCE,
    RANDOM,
    LOOP,
    ;

    public static MusicPlayMode fromRepeatMode(@PlaybackStateCompat.RepeatMode int repeatMode) {
        switch (repeatMode) {
            case PlaybackStateCompat.REPEAT_MODE_ONE:
                return MusicPlayMode.LOOP;
            case PlaybackStateCompat.REPEAT_MODE_INVALID:
            case PlaybackStateCompat.REPEAT_MODE_NONE:
            case PlaybackStateCompat.REPEAT_MODE_ALL:
            case PlaybackStateCompat.REPEAT_MODE_GROUP:
            default:
                return MusicPlayMode.SEQUENCE;
        }
    }

    public static MusicPlayMode fromShuffleMode(@PlaybackStateCompat.ShuffleMode int shuffleMode) {
        switch (shuffleMode) {
            case PlaybackStateCompat.SHUFFLE_MODE_ALL:
            case PlaybackStateCompat.SHUFFLE_MODE_GROUP:
                return MusicPlayMode.RANDOM;
            case PlaybackStateCompat.SHUFFLE_MODE_INVALID:
            case PlaybackStateCompat.SHUFFLE_MODE_NONE:
            default:
                return MusicPlayMode.SEQUENCE;
        }
    }

    public static MusicPlayMode getNext(MusicPlayMode nowMode) {
        switch (nowMode) {
            case SEQUENCE:
                return MusicPlayMode.RANDOM;
            case RANDOM:
                return MusicPlayMode.LOOP;
            case LOOP:
            default:
                return MusicPlayMode.SEQUENCE;
        }
    }
}
