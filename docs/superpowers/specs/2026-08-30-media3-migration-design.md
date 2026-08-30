# Android 端 ExoPlayer/Media2 → Media3 迁移设计

- 日期：2026-08-30
- 状态：待审阅
- 范围：`yunshu_music/android`（原生 Android 代码，不含 Flutter Dart 侧）

## 1. 背景与目标

当前 Android 端使用已进入弃用/仅维护状态的库：

- ExoPlayer v2（`com.google.android.exoplayer:*:2.19.1`）
- `androidx.media2:media2-session:1.3.0`（声明但从未被 `import`，仅通过传递依赖提供 `androidx.media:media` 的 legacy compat 类）

迁移到 Media3（`androidx.media3:*:1.11.0`）的现代架构：`MediaSessionService` + `MediaSession` + `MediaController`。

**硬性目标**：Dart ↔ 原生之间的 MethodChannel/EventChannel 契约**完全不变**。下述原生入口的对外行为必须保持一致：

- MethodChannel `yunshu.music/method_channel`：`init`、`playFromId`、`play`、`pause`、`seekTo`、`skipToPrevious`、`skipToNext`、`setPlayMode`、`getPlayMode`、`getPlayList`、`delPlayListByMediaId`、`clearPlayList`
- EventChannel `yunshu.music/playback_state_event_channel`：`{bufferedPosition, state, position}`
- EventChannel `yunshu.music/metadata_event_channel`：`{mediaId, title, subTitle, duration, musicUri, lyricUri, coverUri}`

## 2. 非目标

- 不改变 Flutter/Dart 侧任何代码。
- 不重构 `MusicPlayDataService` 的队列/顺序/随机/循环**语义**（`MediaItem` 类型换掉，逻辑保留）。
- 不引入 Android Auto / 系统媒体浏览树（原 `MediaBrowserServiceCompat` 的 browse 功能，其唯一消费方是 App 自身，已废弃）。

## 3. 关键设计决策（已与需求方确认）

| 决策点 | 选择 | 理由 |
|---|---|---|
| 架构 | **策略A：单曲引擎 + 自定义队列** | 行为与现状最接近；Media3 `MediaSession.Callback` 没有 `onPlay/onPause/onSkipToNext/onSeekTo`，但单曲引擎 + 自定义命令桥可完整复现现状 |
| 库/浏览树 | `MediaSessionService`（砍掉 browse） | 浏览树唯一消费方是 App 自身 |
| 队列语义实现 | 服务端集中实现（`MediaPlayerImpl`），Dart + 媒体键 + 通知栏按钮都汇到同一处 | 单一实现，避免客户端/服务端两处逻辑漂移 |
| 封面加载 | **自定义 `MediaNotification.Provider` + Glide** | Media3 默认 `DataSourceBitmapLoader` 不带 App 自身的 OkHttp 签名 interceptor，auth 开启时封面会 403；用 Glide 保留现状并可回退默认封面 |
| 数据模型 | `MediaBrowserCompat.MediaItem` → `androidx.media3.common.MediaItem` | 完整迁移，可整体移除 `androidx.media` 依赖 |

## 4. 依赖改动（`yunshu_music/android/app/build.gradle.kts`）

移除：

```kotlin
implementation("com.google.android.exoplayer:exoplayer-core:2.19.1")
implementation("com.google.android.exoplayer:extension-okhttp:2.19.1")
implementation("androidx.media2:media2-session:1.3.0")
```

新增：

```kotlin
implementation("androidx.media3:media3-common:1.11.0")
implementation("androidx.media3:media3-exoplayer:1.11.0")
implementation("androidx.media3:media3-datasource-okhttp:1.11.0")
implementation("androidx.media3:media3-session:1.11.0")
```

保留不变：`okhttp:4.12.0`、`mmkv-static:2.2.2`、`glide:4.16.0`、`glide:okhttp3-integration:4.16.0`、`glide:compiler`。

移除后 `androidx.media:media`（内含 `MediaSessionCompat` 等 legacy compat）与 `androidx.media2` 均不再需要。`AndroidManifest.xml` 中的 `androidx.media.session.MediaButtonReceiver` receiver 也一并移除（Media3 的 MediaSessionService 自行处理媒体按钮）。

## 5. 目标架构

```
Flutter (Dart)  ──MethodChannel/EventChannel──▶  MainActivity (MediaController 客户端)
                                                    │  controller.play()/pause()/seekTo()
                                                    │  controller.sendCustomCommand(PLAY_FROM_ID/SKIP_NEXT/SKIP_PREVIOUS)
                                                    ▼
                                            MusicSessionService (extends MediaSessionService)
                                                    │  持单曲 ExoPlayer + MediaSession
                                                    ▼
                                            MediaPlayerImpl (extends MediaSession.Callback implements Player.Listener)
                                                    │  自定义队列逻辑：playFromId/上一曲/下一曲/自动下一曲
                                                    │  player.setMediaItem + prepare + play（单曲）
```

### 组件职责

- **MusicPlayDataService**：队列引擎（顺序/随机/循环），改动仅是把 `MediaBrowserCompat.MediaItem` 换成 `Media3` 的 `MediaItem`，其余逻辑不变。仍是 `MusicChannel` 上的静态单例，客户端与服务端共享。
- **MusicSessionService**（原 `MusicBrowserService`）：持有 `ExoPlayer` 与 `MediaSession`；`onGetSession(controllerInfo)` 返回 session；生命周期/前台服务/通知由 `MediaSessionService` 管理。
- **MediaPlayerImpl**：服务端唯一播放逻辑所在。实现：
  - `MediaSession.Callback`：`onConnect`（声明自定义 session commands）、`onMediaButtonEvent`（返回 true 拦截上下曲）、`onCustomCommand`（处理 Dart 的 `PLAY_FROM_ID/SKIP_NEXT/SKIP_PREVIOUS`）
  - `Player.Listener`：`onMediaItemTransition` / `onPlaybackStateChanged(ENDED)`（自动下一曲）、`onPlayerError`
- **MainActivity**：客户端。持有 `MediaController`；MethodChannel 处理及 EventChannel 推送。
- **MusicNotificationService**：删除。通知改为自实现 `MediaNotification.Provider`（内部用 Glide + `HttpClient` 的 `OkHttp` 加载封面，保留现状 UI 与默认封面回退）。

### Media3 字段/方法与 legacy 对照

| legacy（现行） | Media3（目标） |
|---|---|
| `MediaBrowserCompat.MediaItem.getMediaId()` | `MediaItem.mediaId` |
| `.getDescription().getTitle()` | `mediaMetadata.title` |
| `.getSubtitle()` | `mediaMetadata.artist` |
| `.getDescription().getMediaUri()` | `localConfiguration.uri`（播放源）/ `MediaItem.requestMetadata.mediaUri` |
| `.getDescription().getIconUri()` | `mediaMetadata.artworkUri` |
| `.getDescription().getExtras().getString("lyricUri")` | `mediaMetadata.extras.getString("lyricUri")`（`extras` 为 `Bundle`） |
| `ExoPlayer.Builder(...).setWakeMode(...).setAudioAttributes(...).setMediaSourceFactory(...)` | `androidx.media3.exoplayer.ExoPlayer.Builder(...)` 同名方法保留 |
| `OkHttpDataSource.Factory(HttpClient.getCallFactory())` | `androidx.media3.datasource.okhttp.OkHttpDataSource.Factory(HttpClient.getCallFactory())` |

构造 MediaItem 示例（native 侧从 Flutter 列表构建或从 MusicPlayDataService 取当前曲）：

```java
MediaItem item = new MediaItem.Builder()
    .setMediaId(musicId)
    .setUri(musicUri)
    .setMediaMetadata(new MediaMetadata.Builder()
        .setTitle(name)
        .setArtist(singer)
        .setArtworkUri(coverUri)
        .setExtras(bundle) // lyricUri
        .setDurationMs(duration)
        .build())
    .build();
```

## 6. 数据流（各触发源的去向）

| 触发源 | 路径 |
|---|---|
| `init` | MainActivity：建 `MediaController`（`SessionToken` + `buildAsync`）→ 等连接可用 → 调 Flutter `getMusicList` → 构建 Media3 `MediaItem` 列表 → `MusicPlayDataService.addMusic(list)` → 触发当前曲播放 |
| Dart `play` / `pause` / `seekTo` | `controller.play()` / `pause()` / `seekTo()`（Media3 自动同步 session 状态与通知） |
| Dart `playFromId` | `controller.sendCustomCommand(PLAY_FROM_ID, {id})` → 服务端 `onCustomCommand` → `MusicPlayDataService.playFromMediaId(id)` → 单曲 `setMediaItem+prepare+play` |
| Dart `skipToPrevious` / `skipToNext` | `controller.sendCustomCommand(SKIP_PREVIOUS/SKIP_NEXT)` → 服务端 → `MusicPlayDataService.previous(true)/next(true)` → 单曲播放 |
| 自然播完（单曲结束） | 服务端 `Player.Listener.onPlaybackStateChanged(ENDED)` → `MusicPlayDataService.next(false)` → 单曲播放（与现状 `STATE_ENDED` 分支同语义） |
| 系统媒体键 / 通知栏按钮 | 服务端 `MediaSession.Callback.onMediaButtonEvent` 返回 `true` → 按 KeyEvent 分发到上述同一队列逻辑 |
| 播放状态/元数据推送 | MainActivity `MediaController.Listener`（`onPlaybackStateChanged` / `onMediaMetadataChanged`）→ EventChannel（注意 Media3 MediaMetadata 无 `METADATA_KEY_DURATION` 风格 API，用 `durationMs` 与 `mediaItem.localConfiguration.uri`、`mediaMetadata.extras.getString("lyricUri")` 组装） |

## 7. 通知（自定义 MediaNotification.Provider）

- 实现 `MediaNotification.Provider`，在 `MediaSessionService` 里 `setMediaNotificationProvider(...)`。
- 按钮：上一曲 / 播放暂停 / 下一曲，行为映射到 `MEDIA_BUTTON` 意图（最终进入 `onMediaButtonEvent` → 队列逻辑），保持现有三键布局。
- 封面：用 Glide + `MusicAppGlideModule`（即 `HttpClient` 的签名 `OkHttp`）加载 `mediaMetadata.artworkUri`；失败回退到 `PathUtils.getDataDirectory()/cover/default_cover.jpg`（同现状）。
- 小图标 `R.mipmap.launcher_icon`，channel id 固定（沿用 `"1"`），`startForegroundServiceType = mediaPlayback`（manifest 已声明）。

## 8. 风险与补偿

1. **封面签名（已选对策）**：Media3 默认加载器 `DataSourceBitmapLoader` 上无签名 interceptor；采用自定义 `MediaNotification.Provider` + Glide 加载，避免 403。关注点：Glide 加载需把 `artworkUri`（可能需签名）交给 `HttpClient` 的 OkHttp（现有 `MusicAppGlideModule` 已做），维持现状。
2. **`MediaController` 异步连接**：`buildAsync()` 返回 `ListenableFuture`；`init` 及其依赖（拉列表、发播放入口）必须在 controller 连接成功后再执行，避免 `IllegalStateException`（控制器未连接）。
3. **后台 Flutter 暂停**：EventChannel 无 listener，`events.success()` 需判空（现状已如此）；服务端播放逻辑不依赖 Dart，后台仍可自动下一曲/响应媒体键。
4. **`MediaItem` 去重**：`MusicPlayDataService.addMusic` 直接 `addAll` 不去重；由于采用单曲引擎（不喂歌单），重复不会进入 player 播放列表，但 `MusicPlayDataService` 内部仍按 mediaId 去重/索引（现状逻辑），风险不计。
5. **自定义命令需声明**：`onConnect` 的 `ConnectionResult` 必须把 `PLAY_FROM_ID / SKIP_NEXT / SKIP_PREVIOUS` 加入 `availableSessionCommands`，否则客户端 `sendCustomCommand` 会被拒绝。

## 9. 测试策略

- 手工冒烟（模拟器/真机）：
  - `init` → 自动播放
  - play/pause/seekTo（Dart 控件）
  - 上一曲/下一曲（Dart 控件），顺序/随机/循环三模式各验证一次
  - 自然播完自动下一曲
  - 后台播放时通知栏按钮（上一曲/播放暂停/下一曲）→ 走自定义队列
  - 蓝牙/耳机媒体键（上一曲/下一曲）
  - 封面显示（auth 开启时也能加载到封面）
- 构建验证：`gradlew :app:assembleDebug` 确保编译通过；确认无残留 `com.google.android.exoplayer2` / `android.support.v4.media` / `androidx.media2` 引用。

## 10. 受影响文件清单

新增/改写：

- `yunshu_music/android/app/build.gradle.kts`（依赖）
- `yunshu_music/android/app/src/main/AndroidManifest.xml`（移除 MediaButtonReceiver，确认 service 声明）
- `.../channel/MusicChannel.java`（`musicPlayDataService` 类型引用随 `MediaItem` 变更）
- `.../service/MusicPlayDataService.java`（`MediaItem` 类型迁移）
- `.../service/MusicSessionService.java`（由 MusicBrowserService 改写）
- `.../service/MediaPlayerImpl.java`（MediaSession.Callback + Player.Listener + 自定义命令/媒体按钮）
- `.../service/MusicNotificationProvider.java`（新增，替换 MusicNotificationService）
- `.../MainActivity.java`（MediaController 客户端 + Method/EventChannel）
- `.../util/HttpClient.java`（`getCallFactory()` 用法兼容，可能不变）
- `.../util/MusicAppGlideModule.java`（可能不变）

删除：

- `.../service/MusicBrowserService.java`
- `.../service/MusicNotificationService.java`
