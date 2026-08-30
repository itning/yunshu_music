# Windows 播放引擎自研（FFmpeg + WASAPI）设计文档

日期：2026-08-30
状态：已与维护者确认设计，待实现

## 1. 背景与动机

`music_channel_windows`（Windows 播放的联邦插件实现）当前通过 `audioplayers` 包播放音频，其 Windows 平台包 `audioplayers_windows`（Media Foundation 实现）存在：

1. **维护负担**：上游 issue #1635（在非平台线程发送 EventSink 导致崩溃/丢事件）长期未发版修复，仓库被迫 vendor 4.2.1 + PR #1961 补丁（`audioplayers_windows/` 目录 + app 级 `dependency_overrides`）。
2. **格式/协议兼容性**：Media Foundation 解复用器覆盖面窄（部分 flac/ogg/流媒体姿势不支持）；FFmpeg 协议层直接支持 http/https/重定向/代理/reconnect。
3. **掌控核心链路**：希望拥有 解复用 → 解码 → 重采样 → 渲染 全链路，为后续功能打基础。

## 2. 目标 / 非目标

**目标**

- 在 `music_channel_windows` 内自建 Windows 播放引擎：FFmpeg（解复用+解码+重采样）+ WASAPI 共享模式（渲染）
- 替换 Dart 侧 `AudioPlayer` 用法，app 在 Windows 构建中不再运行 audioplayers 代码
- 移除 vendored `audioplayers_windows/` 目录与 `dependency_overrides`
- 对现有业务代码（SMTC、托盘、任务栏进度、播放列表逻辑）零侵入

**非目标**

- 不改动 iOS / macOS / Web / Android 端（`music_channel_ios`、`music_channel_macos` 继续用 audioplayers）
- 不做 gapless、均衡器、倍速、多实例同时播放（现有业务为单播放器）
- 不支持本地文件 / 字节流音源（现有业务只用 HTTP URL；FFmpeg 天然支持，需要时再开）

## 3. 总体架构

```
music_channel_windows/
├── lib/music_channel_windows.dart      # 改：AudioPlayer → FfmpegPlayer，事件流适配
├── lib/ffmpeg_player.dart              # 新：Dart 播放器封装（MethodChannel + EventChannel）
└── windows/
    ├── CMakeLists.txt                  # 改：下载并链接 FFmpeg、bundle DLL
    ├── music_channel_windows_plugin.cpp # 改：注册音频引擎通道
    ├── ffmpeg_engine.h/.cpp            # 新：引擎生命周期、命令处理、状态机
    ├── ffmpeg_decoder.h/.cpp           # 新：FFmpeg 解复用+解码+重采样循环（decode 线程）
    ├── wasapi_output.h/.cpp            # 新：WASAPI 共享模式渲染（事件驱动回调线程）
    └── ring_buffer.h                   # 新：有界阻塞环形缓冲（解码→渲染，带背压）
```

引擎是一个自包含 C++ 单元；Flutter 侧只在插件注册时创建、销毁时关闭。

## 4. C++ 引擎设计

### 4.1 线程模型

| 线程 | 归属 | 职责 |
|---|---|---|
| Platform 线程 | Flutter | MethodChannel 命令入口；**所有** EventSink 调用都发生在此线程 |
| Decode 线程 | 引擎自建 | `av_read_frame → avcodec_send/receive_frame → swr_convert →` 写环形缓冲 |
| WASAPI 回调线程 | 系统 | 事件到来时 `GetBuffer` 从环形缓冲取 PCM 写入；维护精确播放位置 |

引擎工作线程到 platform 线程的消息投递用任务队列（参照 vendored 包中 `platform_thread_handler` 的思路，但代码自研）：引擎线程只投递 lambda，由 platform 线程取出执行 EventSink——从根上规避 issue #1635 一类问题。

### 4.2 播放管线

```
HTTP(S) URL（FFmpeg 协议层：重定向/代理/reconnect 选项）
  → avformat_open_input + avformat_find_stream_info（选最佳音频流）
  → avcodec 打开解码器（mp3/flac/ogg/aac/m4a/opus/wav… LGPL 构建全含）
  → swresample 转为 WASAPI 混音格式（GetMixFormat，通常 float32/48kHz/立体声/交织）
  → 环形缓冲（容量约 500ms，满则 decode 线程阻塞 = 天然背压）
  → WASAPI 共享模式（AUDCLNT_SHAREMODE_SHARED + AUDCLNT_STREAMFLAGS_EVENTCALLBACK）
```

- **音量**：`ISimpleAudioVolume::SetMasterVolume`（会话音量，0.0–1.0，不动系统音量、不改 PCM）。
- **网络中断保护**：`AVFormatContext.interrupt_callback`，保证 teardown/切歌时阻塞中的网络读立刻返回。
- **格式转换**：FFmpeg 输出 planar，swr 直接输出 packed float（`AV_SAMPLE_FMT_FLT`），声道数对齐混音格式。

### 4.3 核心语义

- **prepared**：`find_stream_info` 成功且解码器打开后发出；**duration** 事件随之发出（流媒体无 duration 则报 null，与现有 Dart 逻辑兼容）。
- **state**：resume/pause 命令生效后发出 `{playing: bool}`（替代 audioplayers 的 `onPlayerStateChanged`）。
- **position**：WASAPI 回调线程以约 200ms 节流上报；位置 = 已提交帧数 − `GetCurrentPadding()`。
- **pause/resume**：decode 线程挂起 + `IAudioClient::Stop()/Start()`（两端缓冲保留，恢复即续播）。
- **seek**：decode 线程暂停 → 清空环形缓冲与 WASAPI 缓冲 → `av_seek_frame`（`AVSEEK_FLAG_BACKWARDS`，按时间戳）→ `avcodec_flush_buffers` → 恢复解码 → 发 **seekComplete**。
- **complete**：decode 线程读到 `AVERROR_EOF` 且环形缓冲排空 → 发 **complete**（触发现有 Dart 切歌逻辑；单曲循环由上层播放模式处理，引擎行为等价于 `ReleaseMode.stop`）。
- **切歌 / setSource**：interrupt callback 唤醒阻塞读 → 停 decode 线程 → 释放 WASAPI 与 FFmpeg 上下文 → 开新管线。play(url) = setSource(url) + 自动开始。

## 5. 通道协议

**MethodChannel `music_channel_windows/audio`**（单实例，命令均异步）：

| 方法 | 参数 | 返回 |
|---|---|---|
| `setSource` | `{url: String}` | `void`（结果经事件回报） |
| `play` | `{url: String}` | `void` |
| `resume` / `pause` | – | `void` |
| `seek` | `{positionMs: int}` | `void`（完成经 seekComplete 事件） |
| `setVolume` | `{volume: double}` | `void` |
| `dispose` | – | `void` |

**EventChannel `music_channel_windows/audio/events`**：

```dart
{'event': 'prepared', 'durationMs': int?}   // 携带 duration（流媒体无则为 null），不单独发 duration 事件
{'event': 'state', 'playing': bool}
{'event': 'position', 'positionMs': int}
{'event': 'seekComplete'}
{'event': 'complete'}
{'event': 'error', 'code': String, 'message': String}  // 打开失败/网络中断/解码失败
```

## 6. Dart 侧集成

新增 `lib/ffmpeg_player.dart`：`FfmpegPlayer` 暴露 `setSourceUrl(url)` / `play(url)` / `resume()` / `pause()` / `seek()` / `setVolume()` / `dispose()` 与流 `onPositionChanged`、`onPrepared`、`onDurationChanged`、`onSeekComplete`、`onComplete`、`onError`、`onPlayerStateChanged`——与现有 `AudioPlayer` 用法一一对位。

`music_channel_windows.dart` 改动点（其余零改动）：

- `_player = AudioPlayer(...)` → `_player = FfmpegPlayer()`；删除 `setReleaseMode`/`setPlayerMode`（引擎默认行为即 stop-on-complete）。
- `onPositionChanged` / `onPlayerStateChanged` 订阅源替换。
- `eventStream` 的 switch 拆为对 `onPrepared`（携带 duration，同时驱动 `onDurationChanged`）、`onComplete`、`onSeekComplete`、`onError` 的订阅；prepared 后置 `MusicStatus.paused`。
- 退出菜单的 `_player.dispose()` 保留。

`music_channel_windows/pubspec.yaml`：删除 `audioplayers: ^6.5.1`。

## 7. FFmpeg 获取与构建

- **来源**：BtbN FFmpeg-Builds 的 `win64-lgpl-shared` 变体（仅 LGPL 组件，动态链接与本项目 Apache 2.0 兼容；**不得**用 full/GPL 构建）。
- **版本锁定**：在插件 `CMakeLists.txt` 顶部定义 `FFMPEG_VERSION` + 下载 URL + `SHA256`（实现时填入当时 7.x 稳定版实际值），`file(DOWNLOAD)` 校验哈希。
- **缓存**：下载/解压到 `$ENV{TEMP}/yunshu_music_ffmpeg`（跨构建共享），存在且哈希匹配即跳过下载。
- **链接**：只链 `avutil / avformat / avcodec / swresample` 四个导入库；对应 DLL（及它们相互间的依赖 DLL）追加进 `music_channel_windows_bundled_libraries`，由 Flutter 随 app 打包。
- **LGPL 合规**：插件 README 注明 FFmpeg 版本、来源链接、源码获取方式与许可证声明。

## 8. 依赖清理

事实依据（已核实）：

- `music_channel_ios`、`music_channel_macos` 仍依赖 `audioplayers` → `audioplayers_windows`（官方版）仍是全平台图中的传递依赖，Windows 构建会把它编译进 runner（`generated_plugins.cmake` 可见）。
- vendored 目录与官方 4.2.1 的全部差异 = PR #1961（线程修复）及其配套编译修复；官方 4.2.1 本身可在 MSVC 下正常编译。

清理步骤：

1. 删除 app `pubspec.yaml` 中 `audioplayers_windows` 的 `dependency_overrides` 及注释。
2. 删除仓库根部 vendored `audioplayers_windows/` 目录。
3. `flutter pub get` 后确认官方 4.2.1 正常解析、Windows 构建通过。官方包在 Windows 构建中成为**编译进但运行时永不调用**的死代码（插件注册后无人向其通道发消息），issue #1635 的运行时 bug 不会触发——无需再跟踪上游发版。

## 9. 错误处理

- 打开失败（DNS/HTTP 4xx/5xx、超时）、网络读取中断、解码失败 → `error` 事件；Dart 侧记日志（现有行为对错误也是忽略，后续要加"失败自动切下一首"再扩展）。
- 热重启/窗口关闭：插件析构 → interrupt callback 唤醒 decode 线程 → 停 WASAPI → 关 FFmpeg 上下文，无泄漏退出。
- underrun（环形缓冲暂时为空）：渲染静音帧，等待解码追上，不报错。

## 10. 测试策略

C++ 侧无测试框架引入计划，以下列手动清单验收（`flutter run -d windows`）：

1. 播放 / 暂停 / 继续 / seek（含 >4 分钟长音频的远端 seek）
2. 音量调节（含静音）
3. 自然播完自动切歌、手动上下曲、随机/顺序/单曲循环模式
4. 格式：mp3、flac、ogg、m4a(aac)、wav（对齐曲库实际）
5. 网络断开与恢复的表现（error 事件、不崩溃）
6. SMTC（系统媒体控制）、托盘菜单、任务栏进度条联动
7. 热重启后无残留音频/无崩溃
8. `flutter pub deps` 无 audioplayers_windows path 依赖；确认打包产物含 4+ 个 FFmpeg DLL

## 11. 风险与备注

- BtbN 为个人维护的构建源；如不可用可换 gyan.dev 的 LGPL 变体或共享镜像，URL/哈希集中定义便于替换。
- WASAPI 共享模式按混音格式输出，采样率/声道由系统混音器决定，swr 目标参数在打开音频客户端时动态获取。
- `audioplayers` 6.x 若未来把平台依赖改为按平台声明，官方 `audioplayers_windows` 或彻底移出 Windows 构建图，属额外收益。
