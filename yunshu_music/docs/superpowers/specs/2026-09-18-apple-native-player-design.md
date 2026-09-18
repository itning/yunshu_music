# Apple 原生播放器迁移设计

## 目标

在 macOS 和 iOS 移除 `audioplayers`，以 Apple 的 AVFoundation `AVPlayer`
承担音频播放。Windows 继续使用现有的 FFmpeg + WASAPI 实现。迁移不得改变
应用现有的播放列表、鉴权 URL 签名、播放模式或 Dart 上层调用接口。

Apple 平台的最低部署版本统一为 macOS 26.0 与 iOS 26.0；项目使用 Xcode 27
及其 SDK 构建。不会为低于该基线的系统保留兼容代码。

## 架构

`MusicChannelMacOS` 和 `MusicChannelIos` 继续负责平台无关的播放协调：管理播放
列表、当前曲目、顺序/随机/循环模式、已签名的音乐 URL、元数据以及向应用发出的
播放状态事件。

各插件新增一个 Dart 侧 `NativeAudioPlayer` 适配器。该适配器封装专属的 Flutter
方法通道和事件通道，并向现有协调层提供下列统一接口：

- 命令：`setSource`、`play`、`resume`、`pause`、`seek`、`setVolume`、`dispose`。
- 事件：`prepared(duration)`、`position`、`state(playing)`、`seekComplete`、
  `complete`、`error(message)`。

macOS 与 iOS 的 Swift 插件各自持有一个 `AVPlayer`。插件负责创建和替换
`AVPlayerItem`、监听 ready/failed 状态、注册周期性时间观察器、监听播放结束以及
将原生事件发送回 Dart。平台插件分开实现，以保持既有 federated plugin 结构和各平台
生命周期处理清晰；两者使用相同的通道契约。

## 数据与控制流

1. Dart 现有逻辑选择曲目并生成已签名 URL。
2. `NativeAudioPlayer` 调用原生 `setSource` 或 `play`。Swift 用该 URL 创建
   `AVPlayerItem`，并在替换旧 item 时移除其观察器。
3. 项目可播放后，原生侧发送 `prepared`（时长）；周期性时间观察器发送 `position`；
   播放/暂停变化发送 `state`。
4. Dart 将事件转换为既有的 `MusicStatus`、进度与元数据流。`complete` 继续走
   `next(false)` 和 `initPlay(autoStart: true)`，从而保持播放模式语义。
5. Dart 发起 seek 后，原生侧完成定位并发送 `seekComplete`。音量直接映射至
   `AVPlayer.volume`。

## 平台集成

### iOS

将播放器实现并入既有 Swift 插件，保留 AVAudioSession 的 playback 配置、远程命令
中心、锁屏元数据、耳机拔出和音频中断通知。远程控制仍先通知 Dart，再通过统一播放器
命令执行。播放状态改变时，同步 `MPNowPlayingInfoCenter` 的播放状态，确保锁屏显示
与实际播放一致。

### macOS

将播放器实现并入既有 Swift 插件。Dart 侧保留 `tray_manager`、`window_manager`、
托盘菜单和窗口标题更新；菜单操作调用统一播放器接口。macOS 不引入 FFmpeg 或额外
原生二进制。

## 错误处理与资源管理

- URL 无效、AVPlayerItem 失败或加载失败时，原生侧发送 `error(message)`；Dart 停止
  播放状态更新，但保留当前曲目和播放列表，且不自动跳到下一首。
- 每次替换 item 或 dispose 时移除 KVO、结束通知与周期性时间观察器，避免重复事件和
  保留循环。
- `dispose` 在应用退出前停止播放器并释放所有观察器。现有 macOS 托盘“退出”流程改为
  调用该接口后退出。

## 变更范围

- `music_channel_macos`：删除 `audioplayers` 依赖，新增 Dart 适配器并扩展 Swift
  插件；Podspec 设为 macOS 26.0。
- `music_channel_ios`：删除 `audioplayers` 依赖，新增 Dart 适配器并扩展 Swift
  插件；Podspec、应用 Podfile 和 Xcode 项目统一为 iOS 26.0。
- 主 macOS Podfile 和 Runner Xcode 项目的所有构建配置统一为 macOS 26.0。
- 重新解析依赖，更新锁文件和自动生成的插件注册文件，以移除 audioplayers 的 Apple
  平台注册与传递依赖。
- Windows FFmpeg、WASAPI、SMTC 及其 Dart 实现不改动。

## 验证

- 为 Dart 适配器补充方法通道调用与事件映射测试。
- 分别在 macOS 26 与 iOS 26 设备/模拟器验证：首次加载、播放、暂停恢复、定位、切歌、
  自动下一首、音量与网络加载失败。
- iOS 额外验证锁屏控制和元数据、音频中断以及耳机拔出后暂停。
- 执行依赖解析、Dart 静态分析与相关测试；构建 macOS 和 iOS 目标，确认不再链接或注册
  `audioplayers`。
