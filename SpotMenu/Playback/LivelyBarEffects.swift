import SwiftUI

/// Decorative theme-specific artwork. No audio capture or analysis.
struct LivelyBarEffects: View {
    let style: BarStyle
    let isPlaying: Bool

    var body: some View {
        PlaybackMotionSurface(isPlaying: isPlaying, enabled: true) { time, intensity in
            Canvas { context, size in
                context.opacity = 0.18 + 0.82 * intensity
                switch style {
                case .studio: spectrum(context: &context, size: size, time: time, intensity: intensity)
                case .neon: neon(context: &context, size: size, time: time, intensity: intensity)
                case .blueprint, .ember, .prism:
                    NewThemeEffects.draw(style: style, context: &context, size: size, time: time, intensity: intensity)
                case .radar:
                    WorldThemeEffects.draw(style, context: &context, size: size, time: time, animated: true)
                case .mercury, .solar, .rotation: break // Dedicated full-surface renderers.
                default: RefreshedThemeEffects.draw(style, context: &context, size: size, time: time, energy: intensity)
                }
            }
            .transaction { $0.animation = nil }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Constant-speed travel around a rounded rectangle, including its corners.
    private func rim(_ distance: Double, size: CGSize, inset: Double = 6) -> (CGPoint, Double) {
        let radius = 16.0
        let width = Double(size.width) - inset * 2
        let height = Double(size.height) - inset * 2
        let horizontal = width - radius * 2
        let vertical = height - radius * 2
        let arc = Double.pi * radius / 2
        let lengths = [horizontal, arc, vertical, arc, horizontal, arc, vertical, arc]
        let perimeter = lengths.reduce(0, +)
        var d = distance.truncatingRemainder(dividingBy: perimeter)
        if d < 0 { d += perimeter }
        for (segment, length) in lengths.enumerated() {
            if d <= length {
                switch segment {
                case 0: return (CGPoint(x: inset + radius + d, y: inset), 0)
                case 2: return (CGPoint(x: inset + width, y: inset + radius + d), .pi / 2)
                case 4: return (CGPoint(x: inset + width - radius - d, y: inset + height), .pi)
                case 6: return (CGPoint(x: inset, y: inset + height - radius - d), -.pi / 2)
                default:
                    let corner = (segment - 1) / 2
                    let centers = [CGPoint(x: inset + width - radius, y: inset + radius),
                                   CGPoint(x: inset + width - radius, y: inset + height - radius),
                                   CGPoint(x: inset + radius, y: inset + height - radius),
                                   CGPoint(x: inset + radius, y: inset + radius)]
                    let angle = -.pi / 2 + Double(corner) * .pi / 2 + d / radius
                    return (CGPoint(x: centers[corner].x + cos(angle) * radius,
                                    y: centers[corner].y + sin(angle) * radius), angle + .pi / 2)
                }
            }
            d -= length
        }
        return (CGPoint(x: inset + radius, y: inset), 0)
    }

    private func perimeter(_ size: CGSize, inset: Double = 6) -> Double {
        2 * (Double(size.width + size.height) - inset * 4 - 64) + 32 * .pi
    }

    private func spectrum(context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        let count = 150
        for index in 0..<count {
            let distance = Double(index) / Double(count) * perimeter(size, inset: 3)
            let (point, tangent) = rim(distance, size: size, inset: 3)
            let wave = (sin(time * 4 + Double(index) * 0.22) + sin(time * 2.7 - Double(index) * 0.41) + 2) / 4
            let length = 2 + wave * 9 * intensity
            var tick = Path()
            tick.move(to: point)
            tick.addLine(to: CGPoint(x: point.x - sin(tangent) * length, y: point.y + cos(tangent) * length))
            context.stroke(tick, with: .color(index % 7 < 3 ? .cyan.opacity(0.6) : .mint.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private func neon(context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        for trail in 0..<3 {
            let color: Color = trail == 0 ? .pink : (trail == 1 ? .cyan : .purple)
            for segment in 0..<36 {
                let distance = time * 120 + Double(trail) * perimeter(size, inset: 3) / 3 - Double(segment) * 5
                let (start, _) = rim(distance, size: size, inset: 3)
                let (end, _) = rim(distance + 6, size: size, inset: 3)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                let alpha = pow(1 - Double(segment) / 36, 1.7)
                var glow = context
                glow.addFilter(.blur(radius: 2 + intensity * 3))
                glow.stroke(path, with: .color(color.opacity(alpha * 0.65)), lineWidth: 9)
                context.stroke(path, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

}
