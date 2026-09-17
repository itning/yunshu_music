package top.itning.yunshu_music.service;

import android.net.Uri;
import android.os.Bundle;

import androidx.annotation.Nullable;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;

import com.tencent.mmkv.MMKV;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * @author itning
 * @since 2021/10/12 14:52
 */
public class MusicPlayDataService {
    private static final String NOW_PLAY_MEDIA_ID_KEY = "NOW_PLAY_MEDIA_ID_KEY";
    private static final String PLAY_MODE_KEY = "PLAY_MODE";
    private static final String PLAY_LIST_KEY = "PLAY_LIST";
    private static final String LYRICS_URI_KEY = "lyricUri";
    private final List<MediaItem> MUSIC_LIST = new ArrayList<>();
    private final List<MediaItem> PLAY_LIST = new ArrayList<>();
    private final Set<MediaItem> RANDOM_SET = new HashSet<>();
    private int nowPlayIndex;
    private MediaItem nowPlayMusic;
    private MusicPlayMode playMode;
    private final MMKV kv;

    public MusicPlayDataService() {
        this.nowPlayIndex = -1;
        kv = MMKV.defaultMMKV();
        try {
            String mode = kv.decodeString(PLAY_MODE_KEY, MusicPlayMode.SEQUENCE.name());
            this.playMode = MusicPlayMode.valueOf(mode);
        } catch (Exception e) {
            kv.encode(PLAY_MODE_KEY, MusicPlayMode.SEQUENCE.name());
            this.playMode = MusicPlayMode.SEQUENCE;
        }
    }

    public static MediaItem buildMediaItem(String mediaId, String musicUri, String name, String singer, String coverUri, String lyricUri) {
        Bundle extras = new Bundle();
        if (lyricUri != null) {
            extras.putString(LYRICS_URI_KEY, lyricUri);
        }
        MediaMetadata metadata = new MediaMetadata.Builder()
                .setTitle(name)
                .setArtist(singer)
                .setArtworkUri(coverUri == null ? null : Uri.parse(coverUri))
                .setExtras(extras)
                .build();
        MediaItem.Builder builder = new MediaItem.Builder()
                .setMediaId(mediaId)
                .setMediaMetadata(metadata);
        if (musicUri != null) {
            builder.setUri(musicUri);
        }
        return builder.build();
    }

    @Nullable
    public String getMediaUri(MediaItem item) {
        if (item.localConfiguration == null || item.localConfiguration.uri == null) {
            return null;
        }
        return item.localConfiguration.uri.toString();
    }

    @Nullable
    public CharSequence getTitle(MediaItem item) {
        return item.mediaMetadata.title;
    }

    @Nullable
    public CharSequence getSinger(MediaItem item) {
        return item.mediaMetadata.artist;
    }

    @Nullable
    public Uri getCoverUri(MediaItem item) {
        return item.mediaMetadata.artworkUri;
    }

    @Nullable
    public String getLyricUri(MediaItem item) {
        Bundle extras = item.mediaMetadata.extras;
        return extras == null ? null : extras.getString(LYRICS_URI_KEY);
    }

    public int getNowPlayIndex() {
        return nowPlayIndex;
    }

    public MediaItem getNowPlayMusic() {
        return nowPlayMusic;
    }

    public MusicPlayMode getPlayMode() {
        return playMode;
    }

    public List<MediaItem> getPlayList() {
        return PLAY_LIST;
    }

    public boolean isMusicListEmpty() {
        return MUSIC_LIST.isEmpty();
    }

    public void delPlayListByMediaId(String mediaId) {
        if (nowPlayMusic != null && mediaId.equals(nowPlayMusic.mediaId)) {
            return;
        }
        int removeIndex = -1;
        for (int i = 0; i < PLAY_LIST.size(); i++) {
            if (mediaId.equals(PLAY_LIST.get(i).mediaId)) {
                removeIndex = i;
                break;
            }
        }
        if (-1 == removeIndex) {
            return;
        }
        PLAY_LIST.remove(removeIndex);
        if (removeIndex < nowPlayIndex) {
            nowPlayIndex--;
        }
        String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
    }

    public void clearPlayList() {
        RANDOM_SET.clear();
        PLAY_LIST.clear();
        if (nowPlayMusic != null) {
            PLAY_LIST.add(nowPlayMusic);
            nowPlayIndex = 0;
            String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
            kv.encode(PLAY_LIST_KEY, playListString);
        } else {
            nowPlayIndex = -1;
            kv.removeValueForKey(PLAY_LIST_KEY);
        }
    }

    public void setPlayMode(MusicPlayMode playMode) {
        this.playMode = playMode;
        RANDOM_SET.clear();
        kv.encode(PLAY_MODE_KEY, playMode.name());
    }

    public void addMusic(List<MediaItem> musicList) {
        MUSIC_LIST.clear();
        MUSIC_LIST.addAll(musicList);
        PLAY_LIST.clear();
        nowPlayIndex = -1;
        String playListString = kv.decodeString(PLAY_LIST_KEY, "");

        List<String> playListMusicIdList = Arrays.asList(playListString.split("@"));
        List<MediaItem> playList = new ArrayList<>(playListMusicIdList.size());
        for (String mediaId : playListMusicIdList) {
            MUSIC_LIST.stream().filter(it -> mediaId.equals(it.mediaId)).findFirst().ifPresent(playList::add);
        }
        PLAY_LIST.addAll(playList);

        String nowPlayMediaId = kv.decodeString(NOW_PLAY_MEDIA_ID_KEY);
        if (null != nowPlayMediaId) {
            for (int i = 0; i < PLAY_LIST.size(); i++) {
                if (nowPlayMediaId.equals(PLAY_LIST.get(i).mediaId)) {
                    nowPlayIndex = i;
                    nowPlayMusic = PLAY_LIST.get(i);
                    break;
                }
            }
        }
        if (-1 == nowPlayIndex) {
            this.next(false);
        }
    }

    public void removeMusic(MediaItem music) {
        MUSIC_LIST.remove(music);
    }

    public void playFromMediaId(String mediaId) {
        nowPlayIndex = -1;
        nowPlayMusic = null;
        for (int i = 0; i < MUSIC_LIST.size(); i++) {
            MediaItem item = MUSIC_LIST.get(i);
            if (mediaId.equals(item.mediaId)) {
                nowPlayMusic = item;
                break;
            }
        }
        if (null == nowPlayMusic) {
            return;
        }
        int playListIndex = PLAY_LIST.indexOf(nowPlayMusic);
        if (-1 == playListIndex) {
            PLAY_LIST.add(nowPlayMusic);
            nowPlayIndex = PLAY_LIST.size() - 1;
        } else {
            nowPlayIndex = playListIndex;
        }
        String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.mediaId);
    }

    public void previous(boolean userTrigger) {
        if (MUSIC_LIST.isEmpty()) {
            return;
        }
        if (nowPlayIndex - 1 < 0) {
            switch (playMode) {
                case RANDOMLY:
                    int randomMusicListIndex = getRandom();
                    nowPlayMusic = MUSIC_LIST.get(randomMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(0, nowPlayMusic);
                    nowPlayIndex = 0;
                    break;
                case SEQUENCE:
                    int sequenceMusicListIndex = toSequencePrevious();
                    nowPlayMusic = MUSIC_LIST.get(sequenceMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(0, nowPlayMusic);
                    nowPlayIndex = 0;
                    break;
                case LOOP:
                    if (userTrigger) {
                        int loopMusicListIndex = toSequencePrevious();
                        nowPlayMusic = MUSIC_LIST.get(loopMusicListIndex);
                        PLAY_LIST.remove(nowPlayMusic);
                        PLAY_LIST.add(0, nowPlayMusic);
                        nowPlayIndex = 0;
                    }
                    break;
            }
        } else if (userTrigger || playMode != MusicPlayMode.LOOP) {
            nowPlayIndex--;
            nowPlayMusic = PLAY_LIST.get(nowPlayIndex);
        }
        String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.mediaId);
    }

    public void next(boolean userTrigger) {
        if (MUSIC_LIST.isEmpty()) {
            return;
        }
        if (nowPlayIndex + 1 >= PLAY_LIST.size()) {
            switch (playMode) {
                case RANDOMLY:
                    int randomMusicListIndex = getRandom();
                    nowPlayMusic = MUSIC_LIST.get(randomMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex = PLAY_LIST.size() - 1;
                    break;
                case SEQUENCE:
                    int sequenceMusicListIndex = toSequenceNext();
                    nowPlayMusic = MUSIC_LIST.get(sequenceMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex = PLAY_LIST.size() - 1;
                    break;
                case LOOP:
                    if (userTrigger) {
                        int loopMusicListIndex = toSequenceNext();
                        nowPlayMusic = MUSIC_LIST.get(loopMusicListIndex);
                        PLAY_LIST.remove(nowPlayMusic);
                        PLAY_LIST.add(nowPlayMusic);
                        nowPlayIndex = PLAY_LIST.size() - 1;
                    }
                    break;
            }
        } else if (userTrigger || playMode != MusicPlayMode.LOOP) {
            nowPlayIndex++;
            nowPlayMusic = PLAY_LIST.get(nowPlayIndex);
        }
        String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
        kv.encode(NOW_PLAY_MEDIA_ID_KEY, nowPlayMusic.mediaId);
    }

    private int getRandom() {
        List<MediaItem> canPlayList = MUSIC_LIST.stream()
                .filter(item -> !RANDOM_SET.contains(item))
                .filter(item -> !PLAY_LIST.contains(item))
                .collect(Collectors.toList());
        if (canPlayList.isEmpty()) {
            RANDOM_SET.clear();
            canPlayList = MUSIC_LIST.stream()
                    .filter(item -> !item.equals(nowPlayMusic))
                    .collect(Collectors.toList());
        }
        if (canPlayList.isEmpty()) {
            canPlayList = MUSIC_LIST;
        }
        Random random = new Random();
        int canPlayListIndex = random.nextInt(canPlayList.size());
        MediaItem mediaItem = canPlayList.get(canPlayListIndex);
        RANDOM_SET.add(mediaItem);
        return MUSIC_LIST.indexOf(mediaItem);
    }

    private int toSequenceNext() {
        if (nowPlayIndex == -1) {
            return 0;
        }
        MediaItem mediaItem = PLAY_LIST.get(nowPlayIndex);
        int musicListIndex = MUSIC_LIST.indexOf(mediaItem);
        if (musicListIndex + 1 >= MUSIC_LIST.size()) {
            return 0;
        } else {
            return musicListIndex + 1;
        }
    }

    private int toSequencePrevious() {
        if (nowPlayIndex == -1) {
            return MUSIC_LIST.size() - 1;
        }
        MediaItem mediaItem = PLAY_LIST.get(nowPlayIndex);
        int musicListIndex = MUSIC_LIST.indexOf(mediaItem);
        if (musicListIndex - 1 < 0) {
            return MUSIC_LIST.size() - 1;
        } else {
            return musicListIndex - 1;
        }
    }
}
