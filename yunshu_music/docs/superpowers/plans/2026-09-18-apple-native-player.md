# Apple Native Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Replace audioplayers on macOS and iOS with AVFoundation-backed native player bridges while preserving existing Dart playback behavior.

**Architecture:** MusicChannelMacOS and MusicChannelIos retain queues, signing, and application-state mapping. A NativeAudioPlayer Dart adapter communicates with an AVPlayer owned by each Swift plugin over method and event channels. Windows remains unchanged.

**Tech Stack:** Flutter/Dart, Flutter platform channels, Swift, AVFoundation, MediaPlayer.

**Spec:** docs/superpowers/specs/2026-09-18-apple-native-player-design.md

## Global Constraints

- macOS and iOS minimum deployment targets are exactly 26.0.
- Build with Xcode 27/SDK 27; do not require APIs that exist only in version 27.
- Remove audioplayers from both Apple plugin dependency graphs and generated registrations.
- Do not modify music_channel_windows or its FFmpeg/WASAPI/SMTC implementation.
- Preserve playlist, play-mode, signing, tray/window, audio-session, interruption, and remote-control behavior.
- Do not commit, stage, discard, or overwrite the user's existing changes.

---

## File Structure

- ../music_channel_macos/lib/native_audio_player.dart: macOS typed method/event-channel adapter.
- ../music_channel_macos/test/native_audio_player_test.dart: adapter channel tests.
- ../music_channel_macos/lib/music_channel_macos.dart: existing controller migrated from audioplayers.
- ../music_channel_macos/macos/Classes/MusicChannelMacosPlugin.swift: macOS AVPlayer bridge.
- ../music_channel_ios/lib/native_audio_player.dart: iOS typed adapter.
- ../music_channel_ios/test/native_audio_player_test.dart: iOS adapter channel tests.
- ../music_channel_ios/lib/music_channel_ios.dart: existing controller migrated from audioplayers.
- ../music_channel_ios/ios/Classes/SwiftMusicChannelIosPlugin.swift: iOS AVPlayer and existing media session.
- Apple plugin pubspecs/podspecs, app Podfiles and Runner projects: dependency and 26.0 floor alignment.

### Task 1: Test and implement the macOS Dart adapter

**Files:**
- Create: ../music_channel_macos/lib/native_audio_player.dart
- Create: ../music_channel_macos/test/native_audio_player_test.dart

**Interfaces:**
- Consumes: method channel music_channel_macos/audio; event channel music_channel_macos/audio/events.
- Produces: NativeAudioPlayer with setSourceUrl(String), play(String), resume(), pause(), seek(Duration), setVolume(double), dispose(), volume, and typed event streams.

- [ ] **Step 1: Write failing wrapper tests**

Follow the existing music_channel_windows test/ffmpeg_player_test.dart pattern with macOS channel names. Cover every command plus prepared, position, state, seekComplete, complete, and error events.

~~~
const methodChannel = MethodChannel('music_channel_macos/audio');
const eventChannelName = 'music_channel_macos/audio/events');

await player.setSourceUrl('https://example.com/a.mp3');
await player.seek(const Duration(seconds: 30));
await emitEvent({'event': 'prepared', 'durationMs': 120000});
expect(calls[1].arguments, {'positionMs': 30000});
expect(durations, [const Duration(milliseconds: 120000)]);
~~~

- [ ] **Step 2: Run the test**

Run: flutter test test/native_audio_player_test.dart

Expected: FAIL because NativeAudioPlayer is absent.

- [ ] **Step 3: Implement the adapter**

Use a broadcast StreamController<Map<Object?, Object?>> and one event-channel subscription. Match FfmpegPlayer lifecycle/payload mapping, changing only channel names.

~~~
Stream<Duration> get onPositionChanged => events
    .where((e) => e['event'] == 'position')
    .map((e) => Duration(milliseconds: (e['positionMs'] as num).toInt()));

Future<void> seek(Duration position) => _methodChannel.invokeMethod(
  'seek', {'positionMs': position.inMilliseconds},
);
~~~

Cancel the subscription and close the controller before native dispose.

- [ ] **Step 4: Verify adapter**

Run: dart format lib/native_audio_player.dart test/native_audio_player_test.dart && flutter test test/native_audio_player_test.dart

Expected: all tests PASS.

### Task 2: Add AVPlayer to macOS and migrate orchestration

**Files:**
- Modify: ../music_channel_macos/macos/Classes/MusicChannelMacosPlugin.swift
- Modify: ../music_channel_macos/lib/music_channel_macos.dart
- Modify: ../music_channel_macos/pubspec.yaml
- Modify: ../music_channel_macos/macos/music_channel_macos.podspec

**Interfaces:**
- Consumes: Task 1 NativeAudioPlayer.
- Produces: macOS audio channels; no audioplayers import/dependency.

- [ ] **Step 1: Lock error/completion contract in tests**

~~~
player.onComplete.listen((_) => completed++);
player.onError.listen(errors.add);
await emitEvent({'event': 'complete'});
await emitEvent({'event': 'error', 'message': 'AVPlayerItem failed'});
expect(completed, 1);
expect(errors, ['AVPlayerItem failed']);
~~~

- [ ] **Step 2: Run adapter tests**

Run: flutter test test/native_audio_player_test.dart

Expected: PASS before native work begins.

- [ ] **Step 3: Implement the Swift AVPlayer bridge**

Register method/event channels from Task 1. Maintain an AVPlayer, current AVPlayerItem, KVO observations for status and timeControlStatus, end notification, and periodic-time token. Map setSource, play, resume, pause, seek(positionMs), setVolume(volume), and dispose. Remove KVO, notification observer, and time observer before replacement/dispose.

Emit exactly:

~~~
eventSink?(["event": "prepared", "durationMs": durationMs])
eventSink?(["event": "position", "positionMs": positionMs])
eventSink?(["event": "state", "playing": player.timeControlStatus == .playing])
eventSink?(["event": "seekComplete"])
eventSink?(["event": "complete"])
eventSink?(["event": "error", "message": error.localizedDescription])
~~~

Return Flutter error for invalid command URL and emit error for item failure.

- [ ] **Step 4: Migrate existing macOS controller**

Replace AudioPlayer, UrlSource, PlayerState, and AudioEvent with NativeAudioPlayer. Retain signed URLs, queue behavior, title/tooltip, tray menu, and window handling. Use prepared for duration and complete for the existing next-track flow:

~~~
_playbackState.state = MusicStatus.none;
_playbackStateController.sink.add(_playbackState.toMap());
next(false);
initPlay(autoStart: true);
~~~

Route tray exit through await _player.dispose().

- [ ] **Step 5: Remove dependency and verify package**

Delete audioplayers from pubspec and set macOS podspec platform to 26.0.

Run: flutter pub get && flutter test && dart analyze

Expected: PASS without audioplayers.

### Task 3: Test and implement the iOS Dart adapter

**Files:**
- Create: ../music_channel_ios/lib/native_audio_player.dart
- Create: ../music_channel_ios/test/native_audio_player_test.dart

**Interfaces:**
- Consumes: music_channel_ios/audio and music_channel_ios/audio/events.
- Produces: same NativeAudioPlayer API/payload semantics as Task 1.

- [ ] **Step 1: Write failing iOS tests**

Copy Task 1 coverage, replacing only channels:

~~~
const methodChannel = MethodChannel('music_channel_ios/audio');
const eventChannelName = 'music_channel_ios/audio/events';
~~~

- [ ] **Step 2: Run the test**

Run: flutter test test/native_audio_player_test.dart

Expected: FAIL because the adapter is absent.

- [ ] **Step 3: Implement and verify the iOS adapter**

Implement Task 1's exact API/event mapping under iOS channel names.

Run: dart format lib/native_audio_player.dart test/native_audio_player_test.dart && flutter test test/native_audio_player_test.dart

Expected: PASS.

### Task 4: Integrate AVPlayer with existing iOS media session

**Files:**
- Modify: ../music_channel_ios/ios/Classes/SwiftMusicChannelIosPlugin.swift
- Modify: ../music_channel_ios/lib/music_channel_ios.dart
- Modify: ../music_channel_ios/pubspec.yaml
- Modify: ../music_channel_ios/ios/music_channel_ios.podspec

**Interfaces:**
- Consumes: Task 3 adapter and existing iOS control-channel methods.
- Produces: native audio channels and lock-screen state synchronized from AVPlayer.

- [ ] **Step 1: Extend test with complete/error and run it**

Use Task 2 completion/error assertions against the iOS channel. Run flutter test test/native_audio_player_test.dart; expected PASS.

- [ ] **Step 2: Extend the Swift plugin**

Implement Task 2's AVPlayer ownership, command mapping, KVO, periodic progress, completion, error emission, and cleanup. Retain existing AVAudioSession, remote command center, interruption observer, and route-change observer.

Before emitting a state event synchronize the lock screen:

~~~
let isPlaying = player.timeControlStatus == .playing
MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
eventSink?(["event": "state", "playing": isPlaying])
~~~

- [ ] **Step 3: Migrate iOS Dart controller**

Replace audioplayers commands/events with NativeAudioPlayer. Maintain _isPlayNow from onPlayerStateChanged and use it for toggle, interruption, and headphone pause. Keep lock-screen metadata/time invocations from prepared/position.

- [ ] **Step 4: Remove dependency and verify**

Delete audioplayers, set iOS podspec platform to 26.0, then run flutter pub get && flutter test && dart analyze.

Expected: PASS and dependency graph excludes audioplayers.

### Task 5: Align deployment targets and regenerate integration

**Files:**
- Modify: macos/Podfile and macos/Runner.xcodeproj/project.pbxproj
- Modify: ios/Podfile and ios/Runner.xcodeproj/project.pbxproj
- Modify: pubspec.lock, Apple Pod locks, generated plugin registrants only as tool output requires.

**Interfaces:**
- Consumes: Tasks 2 and 4 dependency/floor changes.
- Produces: every Apple target at 26.0 and no Apple audioplayers registration.

- [ ] **Step 1: Inspect existing macOS edits**

Run: git diff -- macos/Podfile.lock macos/Runner.xcodeproj/project.pbxproj macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme

Expected: identify and preserve unrelated user hunks.

- [ ] **Step 2: Make floors consistent**

Set both Podfile platform declarations to 26.0. Set every MACOSX_DEPLOYMENT_TARGET and IPHONEOS_DEPLOYMENT_TARGET configuration to 26.0.

- [ ] **Step 3: Regenerate dependencies**

~~~
flutter pub get
(cd macos && pod install)
(cd ios && pod install)
~~~

Expected: no audioplayers_darwin in Apple Pod locks or registrants.

- [ ] **Step 4: Verify no stale dependency**

Run: rg -n -i 'audioplayers|AudioPlayer|PlayerState|UrlSource' pubspec.lock macos ios ../music_channel_macos ../music_channel_ios --glob '!**/Pods/**' --glob '!**/.symlinks/**'

Expected: no audioplayers/import/registration matches; AVPlayer only in Swift plugins.

### Task 6: Final verification without commits

**Files:**
- Modify only the smallest responsible file if checks reveal a defect.

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: migration evidence for user review.

- [ ] **Step 1: Run automated verification**

~~~
(cd ../music_channel_macos && flutter test && dart analyze)
(cd ../music_channel_ios && flutter test && dart analyze)
flutter test
dart analyze
~~~

Expected: every command exits 0.

- [ ] **Step 2: Build Apple targets**

~~~
flutter build macos --debug
flutter build ios --debug --no-codesign
~~~

Expected: builds succeed without audioplayers_darwin.

- [ ] **Step 3: macOS 26 smoke test**

Verify remote first load, progress, pause/resume, seek, volume, track change, automatic next, inaccessible URL, and tray exit. Expect no auto-skip after error and tray label matching playback.

- [ ] **Step 4: iOS 26 smoke test**

Verify the standard playback flow, lock-screen controls/metadata/time, headphone unplug pause, and audio interruption pause. Expect lock-screen state to match AVPlayer.

- [ ] **Step 5: Record final state**

Run: git status --short && git diff --check

Expected: no whitespace errors and no commits created.
