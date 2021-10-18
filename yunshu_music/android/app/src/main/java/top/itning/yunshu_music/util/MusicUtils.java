package top.itning.yunshu_music.util;

import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaMetadataCompat;

import java.util.Map;


/**
 * @author itning
 * @since 2021/10/11 13:21
 */
public class MusicUtils {
    public static MediaBrowserCompat.MediaItem to(Map<String, String> music) {
        MediaMetadataCompat metadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, music.get("musicId"))
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_URI, "https://music.itning.top/file?id=" + music.get("musicId"))
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, music.get("name"))
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, music.get("singer"))
                .putString(MediaMetadataCompat.METADATA_KEY_ART_URI, "https://music.itning.top/file/cover?id=" + music.get("musicId"))
                .build();
        return createMediaItem(metadata);
    }

    private static MediaBrowserCompat.MediaItem createMediaItem(MediaMetadataCompat metadata) {
        return new MediaBrowserCompat.MediaItem(
                metadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_PLAYABLE
        );
    }
}