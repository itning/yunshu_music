# 完全 SwiftPM 迁移设计

## 目标

将云舒音乐的 iOS 与 macOS 原生依赖管理从 CocoaPods 完全迁移到 Swift Package
Manager（SwiftPM）。迁移后不再保留 Podfile、Podfile.lock、Pods 工程或本地音乐插件
的 podspec；所有 Apple 平台插件都由 Flutter 自动生成的
`FlutterGeneratedPluginSwiftPackage` 管理。

## 当前状态

主应用已由 Flutter 3.47 自动接入 SwiftPM，但生成的包未包含
`music_channel_macos` 与 `music_channel_ios`。这两个本地插件只有 CocoaPods 描述，
因此 Flutter 目前回退到 CocoaPods 并在构建时产生告警。其余 Apple 平台插件已经被
生成包列为 SwiftPM 依赖。

## 架构

每个本地音乐插件将拥有一个平台专属 Swift 包：

- `macos/music_channel_macos/Package.swift` 与
  `macos/music_channel_macos/Sources/music_channel_macos/`。
- `ios/music_channel_ios/Package.swift` 与
  `ios/music_channel_ios/Sources/music_channel_ios/`。

现有 Swift 插件实现会移动到各自 `Sources` 目录，SwiftPM 成为唯一编译入口。每个
`Package.swift` 使用 Swift tools 5.9，声明相应 Apple 平台最低版本 26.0，导出与
插件目录相匹配的 library product，并通过 Flutter 自动提供的本地 `FlutterFramework`
包依赖 Flutter API。

## 应用迁移

在两个本地插件都能被 Flutter 识别为 SwiftPM 包后：

1. 运行 `flutter pub get` 与各 Apple 平台的 config-only 构建，验证自动生成包列出
   两个音乐插件。
2. 移除 `ios/Podfile`、`ios/Podfile.lock`、`ios/Pods`、`ios/Runner.xcworkspace` 的
   CocoaPods 项目内容，以及 macOS 对应 CocoaPods 文件和工程引用。
3. 依照 Flutter 生成的 SwiftPM 工程结构清理 Xcode 工程内 Pods framework、Pods
   build phase、CocoaPods xcconfig 引用与 workspace 引用；保留 Flutter 的
   `FlutterGeneratedPluginSwiftPackage` 本地包和 prepare pre-action。
4. 删除两个本地插件的 `.podspec`，避免未来重新进入 CocoaPods 路径。

Flutter 的生成文件（`Flutter/ephemeral`、`.dart_tool` 与 build 输出）不作为手工维护
源码；它们只能通过 Flutter 命令重新生成。

## 失败处理

- 若 `flutter pub get` 没有将任一本地音乐插件放入生成 Swift 包，停止删除 CocoaPods，
  检查 `Package.swift` 的目录、target、product 与 FlutterFramework path。
- 若任一第三方插件不支持 SwiftPM，迁移停止；不以禁用 SwiftPM 或保留部分 Pods 的
  方式规避，因为本次目标是完全迁移。
- 仅当 iOS 与 macOS Debug 构建都不调用 `pod install`、不再输出缺失 SwiftPM 支持告警
  时，才删除 CocoaPods 相关受版本控制文件。

## 验证

- `flutter pub get` 后，iOS/macOS 生成的 `Package.swift` 均列出两个本地音乐插件。
- `flutter build macos --debug` 与 `flutter build ios --debug --no-codesign` 成功，输出中
  不含 CocoaPods 回退或 `music_channel_*` 缺失 SwiftPM 支持告警。
- 执行根项目和两个本地音乐插件的 Dart 测试及静态分析。
- 使用 Xcode 打开 Runner 项目时仅显示 Swift Package Dependencies，不显示 Pods 项目或
  Pods framework 引用。
