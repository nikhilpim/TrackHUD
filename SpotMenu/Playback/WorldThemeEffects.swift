import SwiftUI

/// Bounded, deterministic paths: no particle simulation, audio sampling, or per-frame allocation of assets.
enum WorldThemeEffects {
    static func draw(_ style: BarStyle, context: inout GraphicsContext, size: CGSize, time: Double, animated: Bool) {
        switch style {
        case .solar: SolarPlasma.draw(context: &context, size: size, time: time, lively: animated)
        case .radar: radar(context: &context, size: size, time: time, animated: animated)
        default: break
        }
    }

    private static func radar(context: inout GraphicsContext, size: CGSize, time: Double, animated: Bool) {
        let center = CGPoint(x: size.width * 0.84, y: size.height / 2)
        // The background owns the instrument chassis; the lively layer adds only light.
        // This avoids doubling the rings and scales when both canvases are present.
        if !animated {
            for radius in [20.0, 38, 56] {
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(.green.opacity(0.12)), lineWidth: 0.7)
            }
            for index in 0..<50 {
                let x = 22 + Double(index) * (size.width - 44) / 50
                context.fill(Path(CGRect(x: x, y: size.height - 7, width: 0.7, height: index % 5 == 0 ? 5 : 2)), with: .color(BarStyle.radar.accent.opacity(0.35)))
            }
        }
        radarUpperInstrument(context: &context, size: size, time: time, animated: animated)
        if animated {
            let angle = time * 0.55
            for tail in 0..<12 {
                let ray = angle - Double(tail) * 0.035
                var line = Path(); line.move(to: center)
                line.addLine(to: CGPoint(x: center.x + cos(ray) * 55, y: center.y + sin(ray) * 55))
                context.stroke(line, with: .color(BarStyle.radar.accent.opacity(0.20 * (1 - Double(tail) / 12))), lineWidth: 2)
            }
            for index in 0..<6 {
                let phase = Double(index) * 1.3
                let radius = 20 + Double(index % 3) * 12
                let alpha = pow((cos(angle - phase) + 1) / 2, 10) * 0.8
                context.fill(Path(ellipseIn: CGRect(x: center.x + cos(phase) * radius, y: center.y + sin(phase) * radius, width: 3, height: 3)), with: .color(.green.opacity(alpha)))
            }
        }
    }

    private static func radarUpperInstrument(context: inout GraphicsContext, size: CGSize, time: Double, animated: Bool) {
        let accent = BarStyle.radar.accent
        let left = 28.0
        let right = size.width - 28
        let traceEnd = size.width * 0.84 - 24
        // A slow, reversible scan has no wrap seam and uses the existing playback clock.
        let scan = 0.5 - 0.5 * cos(time * 0.55)
        let scanX = left + (traceEnd - left) * scan

        if !animated {
            let band = Path(CGRect(x: left, y: 2, width: right - left, height: 16))
            context.fill(band, with: .linearGradient(
                Gradient(colors: [accent.opacity(0.09), accent.opacity(0.025), .clear]),
                startPoint: CGPoint(x: 0, y: 2), endPoint: CGPoint(x: 0, y: 18)))
            var rail = Path()
            rail.move(to: CGPoint(x: left, y: 3))
            rail.addLine(to: CGPoint(x: right, y: 3))
            // The trace terminates in a raised bearing bracket above the circular scope.
            rail.move(to: CGPoint(x: traceEnd, y: 13))
            rail.addLine(to: CGPoint(x: traceEnd + 12, y: 13))
            rail.addLine(to: CGPoint(x: traceEnd + 19, y: 9))
            rail.addLine(to: CGPoint(x: right, y: 9))
            rail.addLine(to: CGPoint(x: right, y: 13))
            context.stroke(rail, with: .color(accent.opacity(0.30)), lineWidth: 0.7)
        }

        for index in 0...48 {
            let x = left + Double(index) / 48 * (right - left)
            let major = index % 6 == 0
            let proximity = exp(-pow((x - scanX) / 23, 2))
            let alpha = animated ? proximity * 0.52 : (major ? 0.55 : 0.25)
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: 3))
            tick.addLine(to: CGPoint(x: x, y: major ? 8 : 5.5))
            context.stroke(tick, with: .color(accent.opacity(alpha)), lineWidth: major ? 1 : 0.6)
        }

        var trace = Path()
        var previous = radarTracePoint(0, left: left, right: traceEnd)
        trace.move(to: previous)
        for step in 1...112 {
            let point = radarTracePoint(Double(step) / 112, left: left, right: traceEnd)
            if animated {
                let proximity = exp(-pow((point.x - scanX) / 26, 2))
                var segment = Path()
                segment.move(to: previous)
                segment.addLine(to: point)
                context.stroke(segment, with: .color(accent.opacity(proximity * 0.75)),
                               style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            } else {
                trace.addLine(to: point)
            }
            previous = point
        }
        if !animated {
            context.stroke(trace, with: .color(accent.opacity(0.43)), lineWidth: 0.8)
        }

        // Fixed acquisition gates give the upper edge structure even with motion Off.
        for position in [0.21, 0.53, 0.79] {
            let point = radarTracePoint(position, left: left, right: traceEnd)
            let proximity = exp(-pow((point.x - scanX) / 28, 2))
            let alpha = animated ? proximity * 0.65 : 0.46
            var gate = Path()
            gate.move(to: CGPoint(x: point.x - 4, y: 16))
            gate.addLine(to: CGPoint(x: point.x - 4, y: 13.5))
            gate.move(to: CGPoint(x: point.x + 4, y: 16))
            gate.addLine(to: CGPoint(x: point.x + 4, y: 13.5))
            context.stroke(gate, with: .color(accent.opacity(alpha)), lineWidth: 0.8)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.2, y: point.y - 1.2, width: 2.4, height: 2.4)),
                         with: .color(accent.opacity(alpha)))
        }
        if animated {
            let point = radarTracePoint(scan, left: left, right: traceEnd)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 4, width: 14, height: 8)),
                         with: .radialGradient(Gradient(colors: [accent.opacity(0.35), .clear]),
                                               center: point, startRadius: 0, endRadius: 7))
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
                         with: .color(accent.opacity(0.9)))
        }
    }

    private static func radarTracePoint(_ position: Double, left: Double, right: Double) -> CGPoint {
        // Decorative range returns, not an audio waveform. Fixed peaks align with the gates.
        let returns = 3.5 * exp(-pow((position - 0.21) / 0.016, 2))
            + 4.2 * exp(-pow((position - 0.53) / 0.023, 2))
            + 2.8 * exp(-pow((position - 0.79) / 0.018, 2))
        let ripple = sin(position * .pi * 22) * sin(position * .pi) * 0.5
        return CGPoint(x: left + (right - left) * position, y: 13 + ripple - returns)
    }
}

struct AlbumLighting: View {
    @ObservedObject var artwork: ArtworkStore
    var pointer: UnitPoint = .center
    var body: some View {
        PaletteLighting(palette: artwork.palette, pointer: pointer)
    }
}

struct PaletteLighting: View {
    let palette: ArtworkPalette
    var pointer: UnitPoint = .center
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(colors: [palette.primary.color.opacity(0.32), .clear], center: UnitPoint(x: 0.1 + pointer.x * 0.22, y: 0.2), startRadius: 0, endRadius: geometry.size.width * 0.65)
                RadialGradient(colors: [palette.secondary.color.opacity(0.26), .clear], center: UnitPoint(x: 0.9, y: 0.7 + pointer.y * 0.15), startRadius: 0, endRadius: geometry.size.width * 0.5)
            }
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
