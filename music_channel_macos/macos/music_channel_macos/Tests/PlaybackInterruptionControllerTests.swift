import Foundation

@main
struct PlaybackInterruptionControllerTests {
  static func main() {
    testSleepPausesAnActivePlayer()
    testOutputDeviceChangePausesAnActivePlayer()
    testWakeDoesNotResumeOrPauseThePlayer()
    testInterruptionDoesNotPauseAnAlreadyPausedPlayer()
  }

  private static func testSleepPausesAnActivePlayer() {
    var pauses = 0
    let controller = PlaybackInterruptionController(
      isPlaying: { true },
      pause: { pauses += 1 }
    )
    controller.handle(.systemSleep)
    precondition(pauses == 1, "Sleep must pause an active player")
  }

  private static func testOutputDeviceChangePausesAnActivePlayer() {
    var pauses = 0
    let controller = PlaybackInterruptionController(
      isPlaying: { true },
      pause: { pauses += 1 }
    )
    controller.handle(.outputDeviceChanged)
    precondition(pauses == 1, "Output-device change must pause an active player")
  }

  private static func testWakeDoesNotResumeOrPauseThePlayer() {
    var pauses = 0
    let controller = PlaybackInterruptionController(
      isPlaying: { true },
      pause: { pauses += 1 }
    )
    controller.handle(.systemWake)
    precondition(pauses == 0, "Wake must leave the player paused")
  }

  private static func testInterruptionDoesNotPauseAnAlreadyPausedPlayer() {
    var pauses = 0
    let controller = PlaybackInterruptionController(
      isPlaying: { false },
      pause: { pauses += 1 }
    )
    controller.handle(.systemSleep)
    controller.handle(.outputDeviceChanged)
    precondition(pauses == 0, "An already paused player must remain untouched")
  }
}
