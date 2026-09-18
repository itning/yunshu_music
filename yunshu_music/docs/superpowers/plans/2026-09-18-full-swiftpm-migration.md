# Full SwiftPM Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Remove CocoaPods from the iOS and macOS app and make both local music-channel plugins SwiftPM-only packages.

**Architecture:** Each local Apple plugin exposes its existing Swift implementation from a Package.swift target under its platform directory. Flutter's generated FlutterGeneratedPluginSwiftPackage resolves those local packages together with all existing SwiftPM-capable third-party plugins; Runner projects retain only that generated package integration.

**Tech Stack:** Flutter 3.47, Xcode 27, Swift tools 5.9, Swift Package Manager, AVFoundation.

**Spec:** docs/superpowers/specs/2026-09-18-full-swiftpm-migration-design.md

## Global Constraints

- macOS and iOS minimum deployment targets are exactly 26.0.
- CocoaPods is removed completely: no Podfile, Podfile.lock, Runner.xcworkspace, Pods references, or local plugin podspec remains tracked.
- Do not disable SwiftPM or reintroduce a CocoaPods fallback.
- Windows remains unchanged.
- Do not edit Flutter generated ephemeral files by hand; regenerate them with Flutter commands.
- Preserve the existing AVPlayer implementation and all Dart public/plugin interfaces.
- Commit each independently verified task with a focused message.

---

## File Structure

- ../music_channel_macos/macos/music_channel_macos/Package.swift: macOS package declaration.
- ../music_channel_macos/macos/music_channel_macos/Sources/music_channel_macos/MusicChannelMacosPlugin.swift: canonical macOS plugin source.
- ../music_channel_macos/macos/.gitignore: ignores SwiftPM .build and .swiftpm outputs.
- ../music_channel_ios/ios/music_channel_ios/Package.swift: iOS package declaration.
- ../music_channel_ios/ios/music_channel_ios/Sources/music_channel_ios/SwiftMusicChannelIosPlugin.swift: canonical iOS plugin source.
- ../music_channel_ios/ios/music_channel_ios/Sources/music_channel_ios/MusicChannelIosPlugin.h and MusicChannelIosPlugin.m: existing Objective-C registration files, if Flutter requires them in the package target; otherwise remove after verification.
- ../music_channel_ios/ios/.gitignore: ignores SwiftPM output.
- yunshu_music/ios and yunshu_music/macos: remove CocoaPods files and Xcode references, retaining only generated SwiftPM integration.
- yunshu_music/pubspec.lock and Xcode project files: regenerated or updated after the dependency-manager migration.

### Task 1: Package the macOS local plugin for SwiftPM

**Files:**
- Create: ../music_channel_macos/macos/music_channel_macos/Package.swift
- Create: ../music_channel_macos/macos/music_channel_macos/Sources/music_channel_macos/MusicChannelMacosPlugin.swift
- Modify: ../music_channel_macos/macos/.gitignore
- Delete: ../music_channel_macos/macos/Classes/MusicChannelMacosPlugin.swift
- Delete: ../music_channel_macos/macos/music_channel_macos.podspec

**Interfaces:**
- Consumes: FlutterFramework supplied by Flutter at ../FlutterFramework when SwiftPM resolves the plugin.
- Produces: product music-channel-macos and target music_channel_macos containing MusicChannelMacosPlugin.

- [ ] **Step 1: Write the Package.swift manifest**

~~~
 // swift-tools-version: 5.9
 import PackageDescription

 let package = Package(
   name: "music_channel_macos",
   platforms: [.macOS("26.0")],
   products: [.library(name: "music-channel-macos", targets: ["music_channel_macos"])],
   dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
   targets: [
     .target(
       name: "music_channel_macos",
       dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
     )
   ]
 )
~~~

- [ ] **Step 2: Move the existing Swift implementation into the target**

Move MusicChannelMacosPlugin.swift unchanged into Sources/music_channel_macos. Add .build/ and .swiftpm/ to the platform .gitignore. Delete the old Classes copy and podspec so SwiftPM is the only native packaging path.

- [ ] **Step 3: Commit the macOS package**

Run: git add music_channel_macos/macos && git commit -m "build: migrate macOS music plugin to SwiftPM"

### Task 2: Package the iOS local plugin for SwiftPM

**Files:**
- Create: ../music_channel_ios/ios/music_channel_ios/Package.swift
- Create: ../music_channel_ios/ios/music_channel_ios/Sources/music_channel_ios/SwiftMusicChannelIosPlugin.swift
- Create or move: ../music_channel_ios/ios/music_channel_ios/Sources/music_channel_ios/MusicChannelIosPlugin.h
- Create or move: ../music_channel_ios/ios/music_channel_ios/Sources/music_channel_ios/MusicChannelIosPlugin.m
- Modify: ../music_channel_ios/ios/.gitignore
- Delete: ../music_channel_ios/ios/Classes/SwiftMusicChannelIosPlugin.swift
- Delete: ../music_channel_ios/ios/Classes/MusicChannelIosPlugin.h
- Delete: ../music_channel_ios/ios/Classes/MusicChannelIosPlugin.m
- Delete: ../music_channel_ios/ios/music_channel_ios.podspec

**Interfaces:**
- Consumes: FlutterFramework supplied at ../FlutterFramework.
- Produces: product music-channel-ios and target music_channel_ios registering SwiftMusicChannelIosPlugin.

- [ ] **Step 1: Write the Package.swift manifest**

~~~
 // swift-tools-version: 5.9
 import PackageDescription

 let package = Package(
   name: "music_channel_ios",
   platforms: [.iOS("26.0")],
   products: [.library(name: "music-channel-ios", targets: ["music_channel_ios"])],
   dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
   targets: [
     .target(
       name: "music_channel_ios",
       dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
     )
   ]
 )
~~~

- [ ] **Step 2: Move canonical native source into the SwiftPM target**

Move SwiftMusicChannelIosPlugin.swift to Sources/music_channel_ios. Read MusicChannelIosPlugin.h/.m before moving: retain them only if they define Flutter registration code needed by the Swift package; otherwise delete them. Add SwiftPM ignored directories and delete podspec/old Classes paths.

- [ ] **Step 3: Commit the iOS package**

Run: git add music_channel_ios/ios && git commit -m "build: migrate iOS music plugin to SwiftPM"

### Task 3: Regenerate Flutter SwiftPM integration and prove local plugins resolve

**Files:**
- Modify: yunshu_music/pubspec.lock only if Flutter resolution changes it.
- Regenerate: yunshu_music/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
- Regenerate: yunshu_music/macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift

**Interfaces:**
- Consumes: SwiftPM manifests from Tasks 1 and 2.
- Produces: generated plugin packages listing music_channel_macos and music_channel_ios without invoking CocoaPods.

- [ ] **Step 1: Regenerate Flutter configuration**

Run:

~~~
 flutter pub get
 flutter build macos --config-only
 flutter build ios --config-only
~~~

Expected: no pod install invocation.

- [ ] **Step 2: Assert both generated packages include the local plugins**

Run:

~~~
 rg -n "music_channel_macos|music-channel-macos" macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
 rg -n "music_channel_ios|music-channel-ios" ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
~~~

Expected: each output contains both a local package dependency and its library product.

- [ ] **Step 3: Stop if resolution falls back to CocoaPods**

If either command runs pod install or either generated manifest omits a local plugin, do not delete app-level CocoaPods files. Inspect Package.swift product/target naming and FlutterFramework path, fix the manifest, rerun Step 1, and repeat Step 2.

- [ ] **Step 4: Commit regenerated tracked resolution files**

Run: git add yunshu_music/pubspec.lock && git commit -m "build: resolve music plugins through SwiftPM"

### Task 4: Remove CocoaPods from the macOS application project

**Files:**
- Delete: yunshu_music/macos/Podfile
- Delete: yunshu_music/macos/Podfile.lock
- Delete: yunshu_music/macos/Runner.xcworkspace/contents.xcworkspacedata
- Delete: yunshu_music/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
- Modify: yunshu_music/macos/Runner.xcodeproj/project.pbxproj
- Modify: yunshu_music/macos/Flutter/Flutter-Debug.xcconfig and Flutter-Release.xcconfig if they contain CocoaPods includes.

**Interfaces:**
- Consumes: successful macOS SwiftPM resolution from Task 3.
- Produces: a Runner project with FlutterGeneratedPluginSwiftPackage but no CocoaPods reference.

- [ ] **Step 1: Locate all CocoaPods references**

Run: rg -n "Pods|pod install|cocoapods|Podfile" macos/Runner.xcodeproj macos/Flutter macos/Runner.xcworkspace

Expected: enumerate every tracked reference before deletion.

- [ ] **Step 2: Remove only the identified CocoaPods project objects**

Delete Pods build phases, framework/file references, xcconfig include lines, and workspace Pods entry. Retain XCLocalSwiftPackageReference and the FlutterGeneratedPluginSwiftPackage product dependency.

- [ ] **Step 3: Delete tracked CocoaPods files**

Use git rm for Podfile, Podfile.lock, and tracked Runner.xcworkspace files. Do not delete untracked caches broadly.

- [ ] **Step 4: Verify macOS config and build**

Run:

~~~
 rg -n "Pods|pod install|cocoapods|Podfile" macos --glob '!Flutter/ephemeral/**'
 flutter build macos --debug
~~~

Expected: no matches and a successful build with no missing-SwiftPM-plugin warning.

- [ ] **Step 5: Commit macOS app migration**

Run: git add -A macos && git commit -m "build: remove macOS CocoaPods integration"

### Task 5: Remove CocoaPods from the iOS application project

**Files:**
- Delete: yunshu_music/ios/Podfile
- Delete: yunshu_music/ios/Podfile.lock
- Delete: yunshu_music/ios/Runner.xcworkspace/contents.xcworkspacedata
- Delete: yunshu_music/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
- Delete: yunshu_music/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
- Modify: yunshu_music/ios/Runner.xcodeproj/project.pbxproj
- Modify: yunshu_music/ios/Flutter/Debug.xcconfig and Flutter-Release.xcconfig if they contain CocoaPods includes.

**Interfaces:**
- Consumes: successful iOS SwiftPM resolution from Task 3.
- Produces: Runner Xcode project using SwiftPM only.

- [ ] **Step 1: Locate every iOS CocoaPods reference**

Run: rg -n "Pods|pod install|cocoapods|Podfile" ios/Runner.xcodeproj ios/Flutter ios/Runner.xcworkspace

Expected: complete list before destructive edits.

- [ ] **Step 2: Remove project references without touching SwiftPM objects**

Remove CocoaPods build phases, framework/file references, xcconfig include lines, and the Pods workspace entry. Preserve FlutterGeneratedPluginSwiftPackage reference, product dependency, and prepare script.

- [ ] **Step 3: Delete tracked CocoaPods files**

Use git rm only for the listed Podfile, lockfile, and workspace files.

- [ ] **Step 4: Verify iOS config and build**

Run:

~~~
 rg -n "Pods|pod install|cocoapods|Podfile" ios --glob '!Flutter/ephemeral/**'
 flutter build ios --debug --no-codesign
~~~

Expected: no matches and successful iOS build with no missing-SwiftPM-plugin warning.

- [ ] **Step 5: Commit iOS app migration**

Run: git add -A ios && git commit -m "build: remove iOS CocoaPods integration"

### Task 6: Final migration verification

**Files:**
- Modify only the smallest responsible file if verification exposes a defect.

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: a fully SwiftPM Apple build with test evidence.

- [ ] **Step 1: Run all Dart verification**

Run:

~~~
 (cd ../music_channel_macos && flutter test && dart analyze)
 (cd ../music_channel_ios && flutter test && dart analyze)
 flutter test
 dart analyze
~~~

Expected: every test passes; document pre-existing analyzer diagnostics separately from new errors.

- [ ] **Step 2: Rebuild both Apple targets**

Run:

~~~
 flutter build macos --debug
 flutter build ios --debug --no-codesign
~~~

Expected: both builds succeed with no CocoaPods installation/fallback and no music_channel SwiftPM support warning.

- [ ] **Step 3: Inspect the final tracked graph**

Run:

~~~
 git ls-files ios macos ../music_channel_ios/ios ../music_channel_macos/macos | rg "Podfile|Pods|xcworkspace|\.podspec" && exit 1 || true
 rg -n "music_channel_macos|music_channel_ios" macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
 git diff --check
~~~

Expected: no tracked CocoaPods artifacts, both generated Swift packages list their local music plugins, and no whitespace errors.

- [ ] **Step 4: Commit verification-only fixes if any**

If no files changed in Task 6, do not create an empty commit. Otherwise use a focused commit message describing the corrected verification failure.
