# Media3 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Android native media stack from ExoPlayer v2 + `MediaBrowserServiceCompat`/`MediaSessionCompat` to Media3 1.11.0 (`MediaSessionService` + `MediaSession` + `MediaController`), preserving the exact Dart↔native MethodChannel/EventChannel contract.

**Architecture:** Strategy A — a **single-item** Media3 `ExoPlayer` owned by a `MediaSessionService`. All queue logic (play-from-id, prev/next, auto-next on song end, SEQUENCE/RANDOMLY/LOOP) stays centralized on the service side in a `MediaSession.Callback`. The Flutter app drives the player through a `MediaController` on the client (`MainActivity`); queue intents run through custom session commands; system media-buttons/notification prev-next run through `MediaSession.Callback.onMediaButtonEvent`; the notification is a custom `MediaNotification.Provider` that loads cover art via Glide.

**Tech Stack:** Media3 1.11.0 (`media3-common`, `media3-exoplayer`, `media3-datasource-okhttp`, `media3-session`), ExoPlayer builder, OkHttp 4.12.0, MMKV, Glide + okhttp3-integration, Flutter embedding (Java).

**Spec:** `docs/superpowers/specs/2026-08-30-media3-migration-design.md` — the plan argues from the spec; executors read both. Read that spec first.

## Global Constraints

- Dart contract must stay byte-identical: MethodChannel `yunshu.music/method_channel` methods `init`, `playFromId`, `play`, `pause`, `seekTo`, `skipToPrevious`, `skipToNext`, `setPlayMode`, `getPlayMode`, `getPlayList`, `delPlayListByMediaId`, `clearPlayList`; EventChannels `yunshu.music/playback_state_event_channel` (`{bufferedPosition, state, position}`) and `yunshu.music/metadata_event_channel` (`{mediaId, title, subTitle, duration, musicUri, lyricUri, coverUri}`).
- Media3 version pins: `androidx.media3:* = 1.11.0`, `okhttp 4.12.0`, `glide 4.16.0`, `mmkv-static 2.2.2`.
- Do NOT feed the whole catalog/queue to the player — single-item playback only (spec §3). `MusicPlayDataService` retains its queue/mode semantics.
- `androidx.media` and `androidx.media2` must be fully removed by the final task; no `com.google.android.exoplayer2.*` residues.
- Cover art loads through `HttpClient`'s signed OkHttp via Glide (spec §7).
- There is **no unit-test harness** in this app (`src/test`, `src/androidTest` absent). Verification is: `gradlew.bat :app:assembleDebug` compiles, `rg` produces no stale legacy references, and a manual smoke checklist (spec §9). All "run to verify" steps below use compile + grep, and the final task includes the manual smoke checklist.

---

### Task 1: Add Media3 dependencies (keep legacy temporarily)

**Files:**
- Modify: `yunshu_music/android/app/build.gradle.kts`

**Interfaces:**
- Consumes: nothing.
- Produces: Media3 artifacts resolvable so Tasks 2–4 can compile `androidx.media3.*` classes while the legacy deps still exist.

- [ ] **Step 1: Replace the ExoPlayer/Media2 implementation block with Media3 plus temp-kept legacy**

Replace the entire `dependencies { ... }` block (currently):

```kotlin
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.android.exoplayer:exoplayer-core:2.19.1")
    implementation("com.google.android.exoplayer:extension-okhttp:2.19.1")
    implementation("androidx.media2:media2-session:1.3.0")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("com.github.bumptech.glide:okhttp3-integration:4.16.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.16.0")
}
```

with:

```kotlin
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.media3:media3-common:1.11.0")
    implementation("androidx.media3:media3-exoplayer:1.11.0")
    implementation("androidx.media3:media3-datasource-okhttp:1.11.0")
    implementation("androidx.media3:media3-session:1.11.0")
    // Legacy deps kept until Task 5; removed there.
    implementation("com.google.android.exoplayer:exoplayer-core:2.19.1")
    implementation("com.google.android.exoplayer:extension-okhttp:2.19.1")
    implementation("androidx.media2:media2-session:1.3.0")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("com.github.bumptech.glide:okhttp3-integration:4.16.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.16.0")
}
```

- [ ] **Step 2: Verify Gradle resolves Media3**

Run: `gradlew.bat :app:dependencies --configuration debugCompileClasspath`
Expected: lists `androidx.media3:media3-common:1.11.0` etc. (no error).

- [ ] **Step 3: Commit**

```bash
git add yunshu_music/android/app/build.gradle.kts
git commit -m "build(android): add media3 1.11.0 dependencies"
```

---

### Task 2: Migrate MusicPlayDataService to Media3 MediaItem

**Files:**
- Modify: `yunshu_music/android/app/src/main/java/top/itning/yunshu_music/service/MusicPlayDataService.java`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `public static MediaItem buildMediaItem(String mediaId, String musicUri, String name, String singer, String coverUri, String lyricUri)`
  - `public List<MediaItem> getPlayList()`; `public MediaItem getNowPlayMusic()`; `public void addMusic(List<MediaItem> musicList)`; `public void removeMusic(MediaItem music)`; `public String getMediaUri(MediaItem item)`; `public CharSequence getTitle(MediaItem)`; `public CharSequence getSinger(MediaItem)`; `public Uri getCoverUri(MediaItem)`; `public String getLyricUri(MediaItem)`.
  - Queue methods keep the same signatures except the item type is now `MediaItem`.

- [ ] **Step 1: Rewrite the file with Media3 `MediaItem`**

Replace the entire contents of `MusicPlayDataService.java` with:

```java
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

    public void delPlayListByMediaId(String mediaId) {
        if (nowPlayMusic != null && mediaId.equals(nowPlayMusic.mediaId)) {
            return;
        }
        PLAY_LIST.removeIf(it -> mediaId.equals(it.mediaId));
        String playListString = PLAY_LIST.stream().map(it -> it.mediaId).collect(Collectors.joining("@"));
        kv.encode(PLAY_LIST_KEY, playListString);
    }

    public void clearPlayList() {
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
        kv.encode(PLAY_MODE_KEY, playMode.name());
    }

    public void addMusic(List<MediaItem> musicList) {
        MUSIC_LIST.addAll(musicList);
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
        if (nowPlayIndex + 1 >= PLAY_LIST.size()) {
            switch (playMode) {
                case RANDOMLY:
                    int randomMusicListIndex = getRandom();
                    nowPlayMusic = MUSIC_LIST.get(randomMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex++;
                    break;
                case SEQUENCE:
                    int sequenceMusicListIndex = toSequenceNext();
                    nowPlayMusic = MUSIC_LIST.get(sequenceMusicListIndex);
                    PLAY_LIST.remove(nowPlayMusic);
                    PLAY_LIST.add(nowPlayMusic);
                    nowPlayIndex++;
                    break;
                case LOOP:
                    if (userTrigger) {
                        int loopMusicListIndex = toSequenceNext();
                        nowPlayMusic = MUSIC_LIST.get(loopMusicListIndex);
                        PLAY_LIST.remove(nowPlayMusic);
                        PLAY_LIST.add(nowPlayMusic);
                        nowPlayIndex++;
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
```

- [ ] **Step 2: Compile**

Run: `gradlew.bat :app:compileDebugJavaWithJavac`
Expected: BUILD SUCCESSFUL (media3-common now on classpath; legacy `MusicBrowserService`/`MainActivity`/`MediaPlayerImpl` still reference `MediaBrowserCompat.MediaItem` — unchanged, still compiled from legacy `androidx.media`).

- [ ] **Step 3: Commit**

```bash
git add yunshu_music/android/app/src/main/java/top/itning/yunshu_music/service/MusicPlayDataService.java
git commit -m "refactor(android): migrate MusicPlayDataService to media3 MediaItem"
```

---

### Task 3: Rewrite service + player callback + notification provider

This task rewrites three files; it deletes none yet (`MainActivity`/`MusicChannel` still reference `MusicBrowserService` and legacy media, and legacy deps are still present, so everything compiles). The class **name** `MusicBrowserService` is kept in this task (its parent becomes `MediaSessionService`); it is renamed to `MusicSessionService` in Task 4 alongside the client rewrite. All path roots below are `yunshu_music/android/app/src/main/java/top/itning/yunshu_music/`.

**Files:**
- Create: `service/MusicNotificationProvider.java`
- Rewrite: `service/MediaPlayerImpl.java`
- Rewrite (keep name `MusicBrowserService`): `service/MusicBrowserService.java`

**Interfaces:**
- Consumes: `MusicChannel.musicPlayDataService` (a `MusicPlayDataService`): `getNowPlayMusic()` → `MediaItem?`; `buildMediaItem(...)`; `playFromMediaId(String)`; `previous(boolean)`; `next(boolean)`; `getPlayMode()`; `getTitle/getSinger/getCoverUri/getLyricUri/getMediaUri(MediaItem)`.
- Produces (consumed by Task 4 / reused):
  - `public static final String ACTION_PLAY_FROM_ID = "PLAY_FROM_ID"`; `ACTION_SKIP_NEXT = "SKIP_NEXT"`; `ACTION_SKIP_PREVIOUS = "SKIP_PREVIOUS"` on `MediaPlayerImpl`.
  - `MediaPlayerImpl` (extends `MediaSession.Callback` implements `Player.Listener`): `MediaPlayerImpl(MediaSessionService context, ExoPlayer player)`; `handleNext(boolean)`; `handlePrevious(boolean)`; `handlePlayFromId(String)`.
  - `MusicBrowserService` (extends `MediaSessionService`): `onGetSession(ControllerInfo)` returns the `MediaSession`.

- [ ] **Step 1: Create `service/MusicNotificationProvider.java`**

```java
package top.itning.yunshu_music.service;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.graphics.drawable.IconCompat;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.session.CommandButton;
import androidx.media3.session.MediaNotification;
import androidx.media3.session.MediaSession;
import androidx.media3.session.MediaStyleNotificationHelper;

import com.bumptech.glide.Glide;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.transition.Transition;
import com.google.common.collect.ImmutableList;

import java.io.File;

import io.flutter.util.PathUtils;
import top.itning.yunshu_music.MainActivity;
import top.itning.yunshu_music.R;
import top.itning.yunshu_music.channel.MusicChannel;

/**
 * Custom notification provider: builds the previous/play-pause/next media notification and loads
 * cover art via Glide over the signed OkHttp (MusicAppGlideModule).
 */
public class MusicNotificationProvider implements MediaNotification.Provider {

    private final Context context;
    private final NotificationManager notificationManager;

    public MusicNotificationProvider(Context context) {
        this.context = context;
        this.notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    @NonNull
    @Override
    public MediaNotification createNotification(
            @NonNull MediaSession mediaSession,
            @NonNull ImmutableList<CommandButton> mediaButtonPreferences,
            @NonNull MediaNotification.ActionFactory actionFactory,
            @NonNull MediaNotification.Provider.Callback onNotificationChangedCallback) {

        MediaItem item = mediaSession.getPlayer().getCurrentMediaItem();
        String title = item == null || item.mediaMetadata.title == null ? "云舒音乐" : item.mediaMetadata.title.toString();
        CharSequence subTitle = item == null ? null : item.mediaMetadata.artist;
        boolean playing = mediaSession.getPlayer().getPlayWhenReady();
        int iconDrawable = playing ? R.drawable.pause_black : R.drawable.play_black;
        int playPauseCommand = playing ? Player.COMMAND_PAUSE : Player.COMMAND_PLAY;

        NotificationCompat.Action prev = actionFactory.createCustomAction(
                mediaSession,
                IconCompat.createWithResource(context, R.drawable.outline_skip_previous),
                "上一曲",
                MediaPlayerImpl.ACTION_SKIP_PREVIOUS,
                Bundle.EMPTY);
        NotificationCompat.Action playPause = actionFactory.createMediaAction(
                mediaSession,
                IconCompat.createWithResource(context, iconDrawable),
                "播放/暂停",
                playPauseCommand);
        NotificationCompat.Action next = actionFactory.createCustomAction(
                mediaSession,
                IconCompat.createWithResource(context, R.drawable.outline_skip_next),
                "下一曲",
                MediaPlayerImpl.ACTION_SKIP_NEXT,
                Bundle.EMPTY);

        PendingIntent contentIntent = PendingIntent.getActivity(
                context, 0,
                new Intent(context, MainActivity.class)
                        .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                        .setAction(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_LAUNCHER),
                PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1")
                .setContentTitle(title)
                .setContentText(subTitle)
                .setContentIntent(contentIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setDeleteIntent(actionFactory.createNotificationDismissalIntent(mediaSession))
                .addAction(prev)
                .addAction(playPause)
                .addAction(next)
                .setStyle(new MediaStyleNotificationHelper.MediaStyle(mediaSession)
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setCancelButtonIntent(actionFactory.createNotificationDismissalIntent(mediaSession)));

        loadCover(mediaSession, builder, onNotificationChangedCallback);
        return new MediaNotification(1, builder.build());
    }

    private void loadCover(MediaSession mediaSession, NotificationCompat.Builder builder, MediaNotification.Provider.Callback callback) {
        MediaItem item = mediaSession.getPlayer().getCurrentMediaItem();
        if (item == null) {
            return;
        }
        Uri coverUri = MusicChannel.musicPlayDataService.getCoverUri(item);
        if (coverUri == null) {
            return;
        }
        Glide.with(context).asBitmap().load(coverUri).into(new CustomTarget<Bitmap>() {
            @Override
            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                builder.setLargeIcon(resource);
                callback.onNotificationChanged(new MediaNotification(1, builder.build()));
            }

            @Override
            public void onLoadCleared(@Nullable Drawable placeholder) {
            }

            @Override
            public void onLoadFailed(@Nullable Drawable errorDrawable) {
                File file = new File(PathUtils.getDataDirectory(context) + "/cover/default_cover.jpg");
                if (!file.exists()) {
                    return;
                }
                Glide.with(context).asBitmap().load(file).into(new CustomTarget<Bitmap>() {
                    @Override
                    public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                        builder.setLargeIcon(resource);
                        callback.onNotificationChanged(new MediaNotification(1, builder.build()));
                    }

                    @Override
                    public void onLoadCleared(@Nullable Drawable placeholder) {
                    }
                });
            }
        });
    }

    @Override
    public boolean handleCustomCommand(@NonNull MediaSession session, @NonNull String action, @NonNull Bundle extras) {
        return false;
    }

    @NonNull
    @Override
    public MediaNotification.Provider.NotificationChannelInfo getNotificationChannelInfo() {
        // Channel is created in MainActivity.onCreate with id "1".
        return new MediaNotification.Provider.NotificationChannelInfo("1", "播放通知");
    }
}
```

- [ ] **Step 2: Rewrite `service/MediaPlayerImpl.java`**

```java
package top.itning.yunshu_music.service;

import static top.itning.yunshu_music.channel.MusicChannel.musicPlayDataService;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.session.ConnectionResult;
import androidx.media3.session.MediaSession;
import androidx.media3.session.SessionCommand;
import androidx.media3.session.SessionCommands;
import androidx.media3.session.SessionResult;
import androidx.media3.common.util.UnstableApi;

import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

/**
 * Central playback + queue logic. Single-item engine: each play intent resolves the next song via
 * {@link MusicPlayDataService} and plays it fresh on a single-item ExoPlayer.
 */
@UnstableApi
public class MediaPlayerImpl extends MediaSession.Callback implements Player.Listener {

    public static final String ACTION_PLAY_FROM_ID = "PLAY_FROM_ID";
    public static final String ACTION_SKIP_NEXT = "SKIP_NEXT";
    public static final String ACTION_SKIP_PREVIOUS = "SKIP_PREVIOUS";

    private static final String TAG = "MediaPlayerImpl";
    private final MediaSessionService context;
    private final ExoPlayer player;

    public MediaPlayerImpl(@NonNull MediaSessionService context, @NonNull ExoPlayer player) {
        this.context = context;
        this.player = player;
    }

    @NonNull
    @Override
    public ConnectionResult onConnect(@NonNull MediaSession session, @NonNull MediaSession.ControllerInfo controller) {
        SessionCommands commands = new SessionCommands.Builder()
                .add(new SessionCommand(ACTION_PLAY_FROM_ID, Bundle.EMPTY))
                .add(new SessionCommand(ACTION_SKIP_NEXT, Bundle.EMPTY))
                .add(new SessionCommand(ACTION_SKIP_PREVIOUS, Bundle.EMPTY))
                .build();
        return new ConnectionResult.AcceptedResultBuilder(session, controller)
                .setAvailableSessionCommands(commands)
                .build();
    }

    @NonNull
    @Override
    public ListenableFuture<SessionResult> onCustomCommand(
            @NonNull MediaSession session,
            @NonNull MediaSession.ControllerInfo controller,
            @NonNull SessionCommand command,
            @NonNull Bundle args) {
        String action = command.customAction;
        if (ACTION_PLAY_FROM_ID.equals(action)) {
            String id = args.getString("id");
            if (id != null) {
                handlePlayFromId(id);
            }
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        } else if (ACTION_SKIP_NEXT.equals(action)) {
            handleNext(true);
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        } else if (ACTION_SKIP_PREVIOUS.equals(action)) {
            handlePrevious(true);
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        }
        return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED));
    }

    @Override
    public boolean onMediaButtonEvent(@NonNull MediaSession session, @NonNull MediaSession.ControllerInfo controllerInfo, @NonNull Intent intent) {
        KeyEvent keyEvent = null;
        Bundle extras = intent.getExtras();
        if (extras != null && extras.containsKey(Intent.EXTRA_KEY_EVENT)) {
            keyEvent = extras.getParcelable(Intent.EXTRA_KEY_EVENT);
        }
        int keyCode = keyEvent != null ? keyEvent.getKeyCode() : KeyEvent.KEYCODE_UNKNOWN;
        switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_NEXT:
            case KeyEvent.KEYCODE_MEDIA_SKIP_FORWARD:
            case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                handleNext(true);
                return true;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
            case KeyEvent.KEYCODE_MEDIA_SKIP_BACKWARD:
            case KeyEvent.KEYCODE_MEDIA_REWIND:
                handlePrevious(true);
                return true;
            case KeyEvent.KEYCODE_HEADSETHOOK:
                if (player.isPlaying()) {
                    player.pause();
                } else {
                    player.play();
                }
                return true;
            default:
                return false;
        }
    }

    private void handlePlayFromId(String id) {
        Log.d(TAG, "handlePlayFromId " + id);
        musicPlayDataService.playFromMediaId(id);
        playCurrent();
    }

    private void handleNext(boolean userTrigger) {
        Log.d(TAG, "handleNext " + userTrigger);
        player.stop();
        musicPlayDataService.next(userTrigger);
        playCurrent();
    }

    private void handlePrevious(boolean userTrigger) {
        Log.d(TAG, "handlePrevious " + userTrigger);
        player.stop();
        musicPlayDataService.previous(userTrigger);
        playCurrent();
    }

    private void playCurrent() {
        MediaItem item = musicPlayDataService.getNowPlayMusic();
        if (item == null) {
            return;
        }
        player.setMediaItem(item);
        player.prepare();
        player.play();
    }

    @Override
    public void onPlaybackStateChanged(@Player.State int playbackState) {
        if (playbackState == Player.STATE_ENDED) {
            player.stop();
            handleNext(false);
        }
    }

    @Override
    public void onPlayerError(@NonNull PlaybackException error) {
        Log.w(TAG, "onPlayerError ", error);
        Toast.makeText(context, error.getErrorCodeName(), Toast.LENGTH_LONG).show();
    }
}
```

Note: `onMediaButtonEvent` and `onConnect` (deprecated) are `@UnstableApi`. The `@UnstableApi` class annotation silences the opt-in requirement. If the compiler still errors, add `@androidx.annotation.OptIn(UnstableApi.class)` — but the class-level `@UnstableApi` is sufficient.

- [ ] **Step 3: Rewrite `service/MusicBrowserService.java` (extends MediaSessionService; name kept)**

```java
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

import top.itning.yunshu_music.MainActivity;
import top.itning.yunshu_music.util.HttpClient;

/**
 * Media3 MediaSessionService. Owns a single-item ExoPlayer + MediaSession, and drives the custom
 * notification provider (Glide cover art).
 */
@UnstableApi
public class MusicBrowserService extends MediaSessionService {

    private MediaSession session;
    private ExoPlayer player;
    private MediaPlayerImpl callback;

    @Override
    public void onCreate() {
        super.onCreate();
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
```

- [ ] **Step 4: Compile**

Run: `gradlew.bat :app:compileDebugJavaWithJavac`
Expected: BUILD SUCCESSFUL. (MainActivity/MusicChannel still reference legacy media APIs and `MusicBrowserService.class` — name kept, so it compiles; at runtime the legacy browser won't connect until Task 4.)

- [ ] **Step 5: Commit**

```bash
git add yunshu_music/android/app/src/main/java/top/itning/yunshu_music/service/
git commit -m "refactor(android): rewrite service to Media3 MediaSessionService + custom notification provider"
```

---

### Task 4: Rewrite MainActivity to a MediaController client + rename service + update MusicPlayMode

**Files:**
- Rewrite: `MainActivity.java`
- Rename: `service/MusicBrowserService.java` → `service/MusicSessionService.java` and `class MusicBrowserService` → `class MusicSessionService` (update references: MainActivity, AndroidManifest.xml).
- Modify: `service/MusicPlayMode.java` (drop `androidx.media` import).
- Delete: `service/MusicNotificationService.java`

**Interfaces:**
- Consumes: `MusicBrowserService` (from Task 3) renamed to `MusicSessionService`; `MusicPlayDataService.buildMediaItem`, `getPlayList`, `getNowPlayMusic`, `playFromMediaId`, `setPlayMode`, `getPlayMode`, `delPlayListByMediaId`, `clearPlayList`; `MediaPlayerImpl.ACTION_*` constants.
- Produces: the renamed `service/MusicSessionService.class`, and the MediaController client behavior (all MethodChannel/EventChannel methods).

- [ ] **Step 1: Rewrite `service/MusicPlayMode.java`**

```java
package top.itning.yunshu_music.service;

/**
 * @author itning
 * @since 2021/10/12 15:05
 */
public enum MusicPlayMode {
    SEQUENCE,
    RANDOMLY,
    LOOP,
    ;

    public static MusicPlayMode getNext(MusicPlayMode nowMode) {
        switch (nowMode) {
            case SEQUENCE:
                return MusicPlayMode.RANDOMLY;
            case RANDOMLY:
                return MusicPlayMode.LOOP;
            case LOOP:
            default:
                return MusicPlayMode.SEQUENCE;
        }
    }
}
```
(Removed `fromRepeatMode`/`fromShuffleMode` — unused, and they referenced the now-removed `androidx.media` `PlaybackStateCompat`.)

- [ ] **Step 2: Rename class + file to `MusicSessionService`**

Run: `git mv service/MusicBrowserService.java service/MusicSessionService.java`, then rename `class MusicBrowserService` → `class MusicSessionService` and the class doc in the file. The `MediaPlayerImpl` constructor call, `onGetSession`, and `@UnstableApi` need no change.

- [ ] **Step 3: Rewrite `MainActivity.java`**

```java
package top.itning.yunshu_music;

import static top.itning.yunshu_music.channel.MusicChannel.methodChannel;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.ComponentName;
import android.media.AudioManager;
import android.os.Bundle;
import android.util.Log;
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
    private MediaController controller;
    private final PlaybackStateEvent playbackStateEvent = new PlaybackStateEvent();
    private final MetadataEvent metadataEvent = new MetadataEvent();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        MMKV.initialize(this);
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
                default:
                    result.notImplemented();
            }
        });
        super.configureFlutterEngine(flutterEngine);
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
            c.addListener(new MediaController.Listener() {
                @Override
                public void onPlaybackStateChanged(@Player.State int playbackState) {
                    Map<String, Object> map = new HashMap<>((int) (3 / 0.75F + 1.0F));
                    map.put("bufferedPosition", c.getBufferedPosition());
                    map.put("state", playbackState);
                    map.put("position", c.getCurrentPosition());
                    playbackStateEvent.send(map);
                }

                @Override
                public void onMediaMetadataChanged(MediaMetadata metadata) {
                    MediaItem current = c.getCurrentMediaItem();
                    Bundle extras = metadata.extras;
                    Map<String, Object> map = new HashMap<>((int) (7 / 0.75F + 1.0F));
                    map.put("mediaId", current == null ? "" : current.mediaId);
                    map.put("title", metadata.title == null ? "" : metadata.title.toString());
                    map.put("subTitle", metadata.artist == null ? "" : metadata.artist.toString());
                    map.put("duration", metadata.durationMs == null ? 0L : metadata.durationMs);
                    map.put("musicUri", current == null || current.localConfiguration == null || current.localConfiguration.uri == null
                            ? "" : current.localConfiguration.uri.toString());
                    map.put("lyricUri", extras == null || extras.getString("lyricUri") == null ? "" : extras.getString("lyricUri"));
                    map.put("coverUri", metadata.artworkUri == null ? "" : metadata.artworkUri.toString());
                    metadataEvent.send(map);
                }
            });
            onControllerConnected();
        }, getMainExecutor());
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
        MediaController c = controller;
        controller = null;
        if (c != null) {
            c.releaseFuture();
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
```

Add the missing imports at the top of `MainActivity.java`: `import android.os.Bundle;` (already present), `androidx.annotation.Nullable`, `java.util.function.Consumer`, `android.os.Bundle` for the `sendCustomCommand` bundle. Specifically add:

```java
import android.os.Bundle;
import java.util.function.Consumer;
```

(`Bundle` is used in `sendCustomCommand`/`metadata`; `Consumer` is used in `withController`.)

- [ ] **Step 4: Delete `MusicNotificationService.java`**

Run: `git rm service/MusicNotificationService.java`

- [ ] **Step 5: Compile**

Run: `gradlew.bat :app:compileDebugJavaWithJavac`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 6: Commit**

```bash
git add yunshu_music/android/app/src/main/java/top/itning/yunshu_music/
git commit -m "refactor(android): MainActivity to MediaController client; rename service to MusicSessionService"
```

---

### Task 5: Remove legacy dependencies, clean manifest, final verification

**Files:**
- Modify: `yunshu_music/android/app/build.gradle.kts`
- Modify: `yunshu_music/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: final buildable project with no legacy ExoPlayer/Media-compat references.

- [ ] **Step 1: Remove legacy deps from `build.gradle.kts`**

Replace the `dependencies { ... }` block with the final set:

```kotlin
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.media3:media3-common:1.11.0")
    implementation("androidx.media3:media3-exoplayer:1.11.0")
    implementation("androidx.media3:media3-datasource-okhttp:1.11.0")
    implementation("androidx.media3:media3-session:1.11.0")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("com.github.bumptech.glide:okhttp3-integration:4.16.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.16.0")
}
```

(Removed `com.google.android.exoplayer:*` and `androidx.media2:media2-session`.)

- [ ] **Step 2: Update `AndroidManifest.xml`**

Remove the legacy receiver block:

```xml
<receiver
    android:name="androidx.media.session.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```

Update the service to the renamed class and the Media3 service action:

```xml
<service
    android:name=".service.MusicSessionService"
    android:exported="true"
    android:foregroundServiceType="mediaPlayback">
    <intent-filter>
        <action android:name="androidx.media3.session.MediaSessionService" />
    </intent-filter>
</service>
```

- [ ] **Step 3: Compile**

Run: `gradlew.bat :app:assembleDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Verify no stale legacy references**

Run:
```bash
rg -n "com.google.android.exoplayer2|android\.support\.v4\.media|androidx\.media2|MediaBrowserServiceCompat|MediaSessionCompat|MediaControllerCompat|MediaButtonReceiver" yunshu_music/android/app/src
```
Expected: no matches (empty output).

- [ ] **Step 5: Manual smoke checklist (must all pass)**

Run `gradlew.bat :app:installDebug` and verify on a device/emulator:
1. App launch → `init` → auto-start playback of the persisted/current song.
2. Dart play / pause / seekTo drive playback and update progress.
3. Dart skipToPrevious / skipToNext advance correctly in SEQUENCE, RANDOMLY, and LOOP modes.
4. Song reaching its natural end auto-advances (SEQUENCE/RANDOMLY).
5. Notification shows title/artist and previous / play-pause / next buttons; tapping next/previous drives the custom queue.
6. Bluetooth/headset media buttons (next/previous/play-pause) work while backgrounded.
7. Cover art loads via Glide even when authorization/signing is enabled.
8. No crash on background/foreground transition; media controls still route to the custom queue.

- [ ] **Step 6: Commit**

```bash
git add yunshu_music/android/app/build.gradle.kts yunshu_music/android/app/src/main/AndroidManifest.xml
git commit -m "chore(android): drop legacy exoplayer/media2 deps; finalize MediaSessionService manifest"
```
