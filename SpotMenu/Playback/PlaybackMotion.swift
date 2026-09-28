import SwiftUI
import QuartzCore

/// A reversible energy envelope. Phase never resets when playback changes.
struct PlaybackMotionState {
    private(set) var time: Double = 0
    private(set) var energy: Double = 0
    private var origin: Double = 0
    private var target: Double = 0
    private var elapsed: Double = 0
    private var duration: Double = 0
    var needsFrames: Bool { energy != target || target > 0 }

    mutating func setPlaying(_ playing: Bool, animated: Bool) {
        origin = energy
        target = playing ? 1 : 0
        elapsed = 0
        duration = animated ? (playing ? 0.65 : 0.9) : 0
        if !animated { energy = target }
    }

    mutating func advance(by delta: Double) {
        guard delta > 0, needsFrames else { return }
        let previous = energy
        elapsed += delta
        let progress = duration > 0 ? min(1, elapsed / duration) : 1
        let eased = progress * progress * (3 - 2 * progress)
        energy = progress == 1 ? target : origin + (target - origin) * eased
        time += delta * (previous + energy) / 2
    }
}

@MainActor
final class PlaybackMotionDriver: ObservableObject {
    @Published private(set) var state = PlaybackMotionState()

    func run(playing: Bool, enabled: Bool) async {
        guard !Task.isCancelled else { return }
        state.setPlaying(playing && enabled, animated: enabled)
        var previous = CACurrentMediaTime()
        while state.needsFrames && !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: 16_666_667) }
            catch { return }
            guard !Task.isCancelled else { return }
            let now = CACurrentMediaTime()
            // Don't leap ahead after system sleep or a blocked main thread.
            state.advance(by: min(0.05, max(0, now - previous)))
            previous = now
        }
    }
}

/// Owns the frame task for exactly as long as this surface is visible and moving.
struct PlaybackMotionSurface<Content: View>: View {
    let isPlaying: Bool
    let enabled: Bool
    @ViewBuilder let content: (Double, Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var driver = PlaybackMotionDriver()

    private struct Request: Equatable {
        let playing: Bool
        let enabled: Bool
    }

    var body: some View {
        let request = Request(playing: isPlaying, enabled: enabled && !reduceMotion)
        content(driver.state.time, request.enabled ? driver.state.energy : 0)
            .transaction { $0.animation = nil }
            .task(id: request) {
                await driver.run(playing: request.playing, enabled: request.enabled)
            }
    }
}
