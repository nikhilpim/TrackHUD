import SwiftUI

/// The sole progress subscriber in either layout. Decorative siblings receive
/// neither progress notifications nor the slider's animation transactions.
struct PlaybackProgressControls: View {
    @ObservedObject var progress: PlaybackProgress
    let foregroundColor: Color
    let trackColor: Color
    var showsTimes = false
    let seek: (Double) -> Void

    var body: some View {
        HStack {
            if showsTimes { timeLabel(progress.currentTime) }
            CustomSlider(
                value: Binding(get: { progress.currentTime }, set: seek),
                range: 0...max(1, progress.totalTime),
                foregroundColor: foregroundColor,
                trackColor: trackColor
            )
            .frame(maxWidth: .infinity)
            if showsTimes { timeLabel(progress.totalTime) }
        }
    }

    private func timeLabel(_ seconds: Double) -> some View {
        Text(Self.formatTime(seconds, styleMatching: progress.totalTime))
            .font(.body.monospacedDigit())
            .foregroundColor(foregroundColor)
            .fixedSize(horizontal: true, vertical: false)
    }

    static func formatTime(_ seconds: Double, styleMatching total: Double) -> String {
        let s = Int(seconds)
        let t = Int(total)
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        if t / 3600 > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else if (t % 3600) / 60 >= 10 {
            return String(format: "%02d:%02d", m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }
}
