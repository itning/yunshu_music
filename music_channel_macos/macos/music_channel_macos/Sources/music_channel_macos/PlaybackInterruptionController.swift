enum PlaybackInterruption {
  case systemSleep
  case systemWake
  case outputDeviceChanged
}

final class PlaybackInterruptionController {
  private let isPlaying: () -> Bool
  private let pause: () -> Void

  init(isPlaying: @escaping () -> Bool, pause: @escaping () -> Void) {
    self.isPlaying = isPlaying
    self.pause = pause
  }

  func handle(_ interruption: PlaybackInterruption) {
    switch interruption {
    case .systemSleep, .outputDeviceChanged:
      guard isPlaying() else { return }
      pause()
    case .systemWake:
      break
    }
  }
}
