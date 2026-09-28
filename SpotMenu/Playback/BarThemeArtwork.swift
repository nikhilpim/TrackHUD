import SwiftUI

/// Static surfaces remain visible with motion off; all artwork sits behind controls.
struct BarThemeSurface: View {
    let style: BarStyle
    var body: some View {
        Canvas { context, size in
            switch style {
            case .blueprint:
                var grid = Path()
                for x in stride(from: 12.0, to: size.width, by: 12) {
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 8.0, to: size.height, by: 12) {
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
                context.draw(Text("FIG. 01 / AUDIO").font(.system(size: 6, design: .monospaced)).foregroundColor(.white.opacity(0.5)), at: CGPoint(x: 75, y: 7))
            case .ember:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [.clear, style.accent.opacity(0.12)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            case .prism:
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [.cyan.opacity(0.12), .clear, .pink.opacity(0.12)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                let border = Path(roundedRect: CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2), cornerRadius: 21)
                context.stroke(border, with: .linearGradient(Gradient(colors: [.cyan.opacity(0.6), .white.opacity(0.15), .pink.opacity(0.7)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 1.5)
            case .solar, .radar:
                WorldThemeEffects.draw(style, context: &context, size: size, time: 0, animated: false)
            default: RefreshedThemeEffects.draw(style, context: &context, size: size, time: 0, energy: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Mercury is a complete moving material, not an accent laid over a flat theme.
struct MercurySurface: View {
    let isPlaying: Bool
    let motion: VisualizerMotion
    var body: some View {
        PlaybackMotionSurface(isPlaying: isPlaying, enabled: motion != .off) { time, activity in
            Canvas { context, size in
                let energy = 0.05 + ((motion == .gentle ? 0.18 : 0.45) - 0.05) * activity
                let speed = motion == .gentle ? 0.18 : 0.45
                Self.draw(context: &context, size: size, time: time * speed, energy: energy)
            }
            .transaction { $0.animation = nil }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func draw(context: inout GraphicsContext, size: CGSize, time: Double, energy: Double) {
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(bounds), with: .color(Color(red: 0.045, green: 0.055, blue: 0.075)))
        // Broad curved sheets with alternating dark and bright reflections create
        // liquid chrome. Their silhouettes deform continuously, with no random jumps.
        let metal = Gradient(stops: [
            .init(color: Color(white: 0.08), location: 0),
            .init(color: Color(red: 0.44, green: 0.49, blue: 0.56), location: 0.22),
            .init(color: Color(white: 0.96), location: 0.34),
            .init(color: Color(white: 0.24), location: 0.42),
            .init(color: Color(white: 0.07), location: 0.56),
            .init(color: Color(red: 0.59, green: 0.64, blue: 0.72), location: 0.79),
            .init(color: Color(white: 0.90), location: 0.86),
            .init(color: Color(white: 0.13), location: 1)
        ])
        for sheet in 0..<5 {
            let seed = Double(sheet)
            let base = -24 + seed * 32
            var ribbon = Path()
            var crest = Path()
            for step in 0...100 {
                let x = Double(step) / 100 * size.width
                let wave = sin(x * 0.011 + time + seed * 1.5) * (13 + energy * 12)
                    + cos(x * 0.023 - time * 0.7 + seed) * 5
                let y = base + wave
                let point = CGPoint(x: x, y: y)
                if step == 0 { ribbon.move(to: point); crest.move(to: point) }
                else { ribbon.addLine(to: point); crest.addLine(to: point) }
            }
            for step in (0...100).reversed() {
                let x = Double(step) / 100 * size.width
                let y = base + 37 + sin(x * 0.009 + time * 0.8 + seed) * (10 + energy * 10)
                ribbon.addLine(to: CGPoint(x: x, y: y))
            }
            ribbon.closeSubpath()
            context.fill(ribbon, with: .linearGradient(metal,
                startPoint: CGPoint(x: 0, y: base - 15), endPoint: CGPoint(x: 80 * sin(time * 0.3 + seed), y: base + 48)))
            context.stroke(crest, with: .color(.white.opacity(0.22 + energy * 0.2)), lineWidth: 0.7)
        }
        // Rounded pools merge into the ribbons: asymmetric contours and moving
        // specular hotspots make this feel like fluid rather than brushed panels.
        for pool in 0..<5 {
            let seed = Double(pool)
            let center = CGPoint(x: (seed + 0.4) * size.width / 5 + sin(time * 0.4 + seed) * 18,
                                 y: pool % 2 == 0 ? 4 : size.height - 5)
            var shape = Path()
            for step in 0...80 {
                let angle = Double(step) / 80 * .pi * 2
                let lobe = 1 + 0.17 * sin(angle * 3 + time * 0.5 + seed)
                let point = CGPoint(x: center.x + cos(angle) * (32 + energy * 15) * lobe,
                                    y: center.y + sin(angle) * (13 + energy * 8) * lobe)
                if step == 0 { shape.move(to: point) } else { shape.addLine(to: point) }
            }
            shape.closeSubpath()
            let hotspot = CGPoint(x: center.x - 10 + sin(time + seed) * 5, y: center.y - 8)
            context.fill(shape, with: .radialGradient(Gradient(stops: [
                .init(color: .white.opacity(0.95), location: 0),
                .init(color: Color(white: 0.55), location: 0.18),
                .init(color: Color(white: 0.09), location: 0.52),
                .init(color: Color(white: 0.45), location: 0.85),
                .init(color: Color(white: 0.12), location: 1)
            ]), center: hotspot, startRadius: 0, endRadius: 45))
            context.stroke(shape, with: .color(.white.opacity(0.2)), lineWidth: 0.6)
        }
        // Quicksilver beads cling to the rim with bright specular highlights.
        for bead in 0..<9 {
            let seed = Double(bead)
            let x = (seed + 0.5) * size.width / 9 + sin(time * 0.6 + seed) * 12
            let y = bead % 2 == 0 ? 10.0 : size.height - 11
            let radius = 2 + (sin(time + seed) + 1) * (1 + energy * 2)
            let ellipse = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2.5, height: radius * 2))
            context.fill(ellipse, with: .radialGradient(Gradient(colors: [.white, Color(white: 0.6), Color(white: 0.12), Color(white: 0.5)]),
                center: CGPoint(x: x - radius * 0.3, y: y - radius * 0.5), startRadius: 0, endRadius: radius * 2))
        }
        // A fixed smoked-glass reading zone prevents highlights obscuring labels.
        context.fill(Path(bounds), with: .linearGradient(Gradient(stops: [
            .init(color: .black.opacity(0.05), location: 0),
            .init(color: .black.opacity(0.60), location: 0.28),
            .init(color: .black.opacity(0.60), location: 0.76),
            .init(color: .black.opacity(0.10), location: 1)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }
}

enum NewThemeEffects {
    static func draw(style: BarStyle, context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        switch style {
        case .blueprint: blueprint(context: &context, size: size, time: time, intensity: intensity)
        case .ember: ember(context: &context, size: size, time: time, intensity: intensity)
        case .prism: prism(context: &context, size: size, time: time, intensity: intensity)
        default: break
        }
    }

    private static func blueprint(context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        for edge in 0..<2 {
            var trace = Path()
            for step in 0...260 {
                let x = 16 + Double(step) / 260 * (size.width - 32)
                let envelope = pow(sin(Double(step) / 260 * .pi), 2)
                let wave = sin(x * 0.10 - time * 5) + 0.4 * sin(x * 0.25 + time * 7)
                let y = (edge == 0 ? 8.0 : size.height - 8) + wave * (2 + intensity * 5) * envelope
                if step == 0 { trace.move(to: CGPoint(x: x, y: y)) } else { trace.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(trace, with: .color(.cyan.opacity(0.85)), lineWidth: 1.2)
        }
        let x = 16 + (time * 60).truncatingRemainder(dividingBy: size.width - 32)
        context.fill(Path(CGRect(x: x, y: 16, width: 1, height: size.height - 32)), with: .color(.white.opacity(0.12)))
    }

    private static func ember(context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        for index in 0..<36 {
            let seed = Double(index)
            let life = (time * (0.13 + Double(index % 4) * 0.025) + seed * 0.618).truncatingRemainder(dividingBy: 1)
            let x = 14 + (seed * 73).truncatingRemainder(dividingBy: size.width - 28) + sin(time + seed) * (3 + intensity * 10)
            let y = size.height - life * (22 + intensity * 88)
            let radius = (1 + Double(index % 3) * 0.4) * (0.5 + intensity)
            let color = index % 3 == 0 ? Color.orange : BarStyle.ember.accent
            let alpha = (1 - life) * 0.75
            let spark = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius * 1.6))
            var glow = context
            glow.addFilter(.blur(radius: 3))
            glow.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: radius + 4, height: radius + 4)), with: .color(color.opacity(alpha * 0.4)))
            context.fill(spark, with: .color(color.opacity(alpha)))
        }
    }

    private static func prism(context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        for ribbon in 0..<5 {
            let color = Color(hue: (Double(ribbon) * 0.18 + time * 0.025).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 1)
            for edge in 0..<2 {
                var line = Path()
                for step in 0...100 {
                    let x = Double(step) / 100 * size.width
                    let bend = sin(x * 0.013 + time * 1.4 + Double(ribbon) * 0.45)
                    let offset = 3 + Double(ribbon) * 1.2 + (bend + 1) * (2 + intensity * 4)
                    let y = edge == 0 ? offset : size.height - offset
                    if step == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
                }
                var glow = context
                glow.addFilter(.blur(radius: 4))
                glow.stroke(line, with: .color(color.opacity(0.16)), lineWidth: 6)
                context.stroke(line, with: .color(color.opacity(0.5)), lineWidth: 1)
            }
        }
    }
}
