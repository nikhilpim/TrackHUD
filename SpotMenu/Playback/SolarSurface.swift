import SwiftUI
import QuartzCore

/// Monotonic elapsed time, independent of metadata refreshes and wall-clock changes.
/// Pausing freezes the current phase rather than snapping the plasma back to zero.
struct AnimationPhaseClock {
    private var accumulated: Double = 0
    private var startedAt: Double?

    func elapsed(at now: Double) -> Double {
        accumulated + (startedAt.map { max(0, now - $0) } ?? 0)
    }

    mutating func setRunning(_ running: Bool, at now: Double) {
        if running {
            if startedAt == nil { startedAt = now }
        } else if let startedAt {
            accumulated += max(0, now - startedAt)
            self.startedAt = nil
        }
    }
}

struct SolarSurface: View {
    let isPlaying: Bool
    let motion: VisualizerMotion

    var body: some View {
        PlaybackMotionSurface(isPlaying: isPlaying, enabled: motion == .lively) { time, energy in
            SolarFrame(time: time, lively: motion == .lively, energy: energy)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SolarFrame: View {
    let time: Double
    let lively: Bool
    var energy: Double = 1

    var body: some View {
        Canvas { context, size in
            SolarPlasma.draw(context: &context, size: size, time: time, lively: lively, energy: energy)
        }
    }
}

enum SolarPlasma {
    static func offset(x: Double, time: Double, strand: Int, amplitude: Double) -> Double {
        let wave = (sin(x * 0.024 + time * 0.7 + Double(strand)) + 1) / 2
        return 2 + Double(strand) * 1.7 + pow(wave, 4) * amplitude
    }

    private static func slope(x: Double, time: Double, strand: Int, amplitude: Double) -> Double {
        let phase = x * 0.024 + time * 0.7 + Double(strand)
        let wave = (sin(phase) + 1) / 2
        return 4 * pow(wave, 3) * cos(phase) * 0.012 * amplitude
    }

    static func draw(context: inout GraphicsContext, size: CGSize, time: Double, lively: Bool, energy: Double = 1) {
        let activity = lively ? energy : 0
        let amplitude = 4 + 9 * activity
        // Cubic curves eliminate the corners of the old sampled polyline. Slightly
        // wider round strokes avoid subpixel sparkle on shallow, moving crests.
        for edge in 0..<2 {
            let sign = edge == 0 ? 1.0 : -1.0
            let base = edge == 0 ? 0.0 : size.height
            for strand in 0..<4 {
                var path = Path()
                let segments = 32
                let dx = size.width / Double(segments)
                path.move(to: CGPoint(x: 0, y: base + sign * offset(x: 0, time: time, strand: strand, amplitude: amplitude)))
                for index in 0..<segments {
                    let x0 = Double(index) * dx, x1 = x0 + dx
                    let y0 = base + sign * offset(x: x0, time: time, strand: strand, amplitude: amplitude)
                    let y1 = base + sign * offset(x: x1, time: time, strand: strand, amplitude: amplitude)
                    let d0 = sign * slope(x: x0, time: time, strand: strand, amplitude: amplitude)
                    let d1 = sign * slope(x: x1, time: time, strand: strand, amplitude: amplitude)
                    path.addCurve(to: CGPoint(x: x1, y: y1),
                                  control1: CGPoint(x: x0 + dx / 3, y: y0 + d0 * dx / 3),
                                  control2: CGPoint(x: x1 - dx / 3, y: y1 - d1 * dx / 3))
                }
                let color: Color = strand % 2 == 0 ? .orange : .yellow
                context.stroke(path, with: .color(color.opacity(0.025 + 0.035 * activity)),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(color.opacity(0.16 + 0.29 * activity)),
                               style: StrokeStyle(lineWidth: strand == 0 ? 2 : 1.25, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
