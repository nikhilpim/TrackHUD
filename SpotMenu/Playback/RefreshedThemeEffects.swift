import SwiftUI

struct RefreshedThemeSurface: View {
    let style: BarStyle
    let isPlaying: Bool
    let motion: VisualizerMotion

    var body: some View {
        PlaybackMotionSurface(isPlaying: isPlaying, enabled: motion != .off) { time, energy in
            Canvas { context, size in
                RefreshedThemeEffects.draw(style, context: &context, size: size,
                                           time: time, energy: energy * (motion == .gentle ? 0.25 : 1))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Eleven distinct geometries, not palette swaps. Light is concentrated around
/// the perimeter so album art, labels and transport controls remain legible.
enum RefreshedThemeEffects {
    static func draw(_ style: BarStyle, context: inout GraphicsContext, size: CGSize,
                     time: Double, energy: Double) {
        guard style.isRefreshed, size.width > 0, size.height > 0 else { return }
        let strength = 0.35 + 0.65 * energy
        switch style {
        case .aurora:
            for band in 0..<5 {
                let seed = Double(band)
                let path = wave(size: size, base: 3 + seed * 2.2, amplitude: 3 + energy * 6,
                                frequency: 0.012, phase: time * 0.35 + seed * 0.7)
                glow(path, context: &context, color: band % 2 == 0 ? .mint : .purple,
                     width: 5, strength: strength * 0.45)
            }
        case .laser:
            laserEdgeComposition(context: &context, size: size, time: time,
                                 strength: strength, coral: style.accent)
        case .velvet:
            velvetTravelingSilk(context: &context, size: size, time: time,
                                strength: strength, rose: style.accent)
        case .halogen:
            halogenIncandescentChambers(context: &context, size: size, time: time,
                                        strength: strength)
        case .circuit:
            circuitContinuousSignals(context: &context, size: size, time: time, strength: strength)
        case .cascade:
            for index in 0..<44 {
                let seed = Double(index)
                let pulse = (sin(time * 1.5 - seed * 0.55) + 1) / 2
                let length = 2 + (3 + energy * 10) * pulse
                let x = 8 + seed * (size.width - 16) / 43
                let y = index % 2 == 0 ? 0 : size.height - length
                let bar = Path(roundedRect: CGRect(x: x, y: y, width: 2, height: length), cornerRadius: 1)
                context.fill(bar, with: .linearGradient(Gradient(colors: [style.accent.opacity(strength), .cyan.opacity(0.05)]),
                                                        startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + length)))
            }
        case .eclipse:
            eclipseOrbitalCorona(context: &context, size: size, time: time,
                                 strength: strength, violet: style.accent)
        case .opal:
            opalFlowingLenses(context: &context, size: size, time: time, strength: strength)
        case .ribbon:
            for index in 0..<4 {
                let seed = Double(index)
                for edge in 0..<2 {
                    let path = wave(size: size, base: edge == 0 ? 6 : size.height - 6,
                                    amplitude: 3 + energy * 4, frequency: 0.027,
                                    phase: time * 0.6 + seed * .pi / 2)
                    context.stroke(path, with: .color((index % 2 == 0 ? style.accent : .orange).opacity(strength * 0.5)),
                                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
            }
        case .afterglow:
            afterglowFlowingContours(context: &context, size: size, time: time, strength: strength)
        case .mosaic:
            mosaicFoldingTessellation(context: &context, size: size, time: time, strength: strength)
        default: break
        }
    }

    private static func mosaicFoldingTessellation(context: inout GraphicsContext, size: CGSize,
                                                  time: Double, strength: Double) {
        let scale = min(1, size.height / 112)
        let pitch = size.width / 18
        let palette: [Color] = [.cyan, .purple, .mint, Color(red: 0.28, green: 0.44, blue: 1)]
        for edge in 0..<2 {
            var rim = context
            rim.translateBy(x: 0, y: edge == 0 ? 0 : size.height)
            rim.scaleBy(x: 1, y: edge == 0 ? scale : -scale)
            // Shared lattice vertices form two connected jewel rows. Two overscan
            // cells absorb the shear at either end; no tile ever wraps or reseeds.
            for column in -2..<20 {
                for row in 0..<2 {
                    let a = mosaicLatticeVertex(column: column, row: row, pitch: pitch, edge: edge, time: time)
                    let b = mosaicLatticeVertex(column: column + 1, row: row, pitch: pitch, edge: edge, time: time)
                    let c = mosaicLatticeVertex(column: column + 1, row: row + 1, pitch: pitch, edge: edge, time: time)
                    let d = mosaicLatticeVertex(column: column, row: row + 1, pitch: pitch, edge: edge, time: time)
                    let triangles = (column + row) % 2 == 0 ? [[a, b, c], [a, c, d]] : [[a, b, d], [b, c, d]]
                    for (side, points) in triangles.enumerated() {
                        var facet = Path()
                        facet.move(to: points[0])
                        facet.addLine(to: points[1])
                        facet.addLine(to: points[2])
                        facet.closeSubpath()
                        let color = palette[(column + 2 + row * 2 + side + edge) % palette.count]
                        let phase = Double(column) * 0.67 - time * (edge == 0 ? 1.05 : -0.93)
                            + Double(row) * 1.1 + Double(side) * 1.8 + Double(edge)
                        let glint = 0.5 + 0.5 * sin(phase)
                        let light = strength * (0.32 + 0.48 * glint)
                        // Opposing gradient faces read as folding crystal, not an opacity
                        // grid. Heights and shear move independently of the energy envelope.
                        rim.fill(facet, with: .linearGradient(Gradient(colors: [
                            color.opacity(light), color.opacity(light * 0.38)
                        ]), startPoint: points[side == 0 ? 0 : 2],
                            endPoint: points[side == 0 ? 2 : 0]))
                        rim.stroke(facet, with: .color(color.opacity(strength * 0.28)), lineWidth: 0.6)
                        var crease = Path()
                        crease.move(to: points[0])
                        crease.addLine(to: points[2])
                        rim.stroke(crease, with: .color(Color.white.opacity(strength * glint * 0.25)),
                                   lineWidth: 0.65)
                    }
                }
            }
        }
    }

    private static func mosaicLatticeVertex(column: Int, row: Int, pitch: Double,
                                            edge: Int, time: Double) -> CGPoint {
        let seed = Double(column)
        let phase = seed * 0.67 - time * (edge == 0 ? 1.05 : -0.93) + Double(edge) * 1.4
        let shear = 0.20 * sin(phase) + Double(row) * 0.12 * sin(phase * 0.8 + time * 0.31)
        let x = (seed + shear) * pitch
        let depth: Double
        switch row {
        case 0: depth = -4
        case 1: depth = 10 + 3 * sin(phase + 0.8) + 1.5 * sin(seed * 1.1 + time * 0.71)
        default: depth = 23 + 5 * sin(phase - 0.5) + 2 * sin(seed * 1.1 + time * 0.71 + 1)
        }
        // The innermost row stays 16...30 points deep, preserving a dark center.
        return CGPoint(x: x, y: depth)
    }

    private static func afterglowFlowingContours(context: inout GraphicsContext, size: CGSize,
                                                time: Double, strength: Double) {
        let scale = min(1, size.height / 112)
        for edge in 0..<2 {
            let edgeY = edge == 0 ? 0.0 : size.height
            let inward = edge == 0 ? 1.0 : -1.0
            let depthScale = scale * (edge == 0 ? 0.72 : 1)
            let light = strength * (edge == 0 ? 0.58 : 1)
            // Sunset strata remain bottom-heavy; a softer upper echo frames the controls.
            for band in (0..<7).reversed() {
                let seed = Double(band)
                let contour = afterglowContour(width: size.width, edgeY: edgeY,
                                               inward: inward, scale: depthScale,
                                               band: band, edge: edge, time: time)
                let coral = Color(hue: 0.028 + seed * 0.010, saturation: 0.72, brightness: 1)
                let amber = Color(hue: 0.085 + seed * 0.006, saturation: 0.64, brightness: 1)
                var stratum = contour
                stratum.addLine(to: CGPoint(x: size.width + 24, y: edgeY))
                stratum.addLine(to: CGPoint(x: -24, y: edgeY))
                stratum.closeSubpath()
                context.fill(stratum, with: .linearGradient(Gradient(colors: [
                    coral.opacity(light * 0.035), amber.opacity(light * 0.065)
                ]), startPoint: CGPoint(x: 0, y: edgeY),
                    endPoint: CGPoint(x: 0, y: edgeY + inward * 30 * depthScale)))
                let shading = GraphicsContext.Shading.linearGradient(Gradient(colors: [
                    coral.opacity(light * (0.65 - seed * 0.045)),
                    amber.opacity(light * (0.76 - seed * 0.05)),
                    coral.opacity(light * (0.57 - seed * 0.04))
                ]), startPoint: CGPoint(x: 0, y: edgeY),
                    endPoint: CGPoint(x: size.width, y: edgeY))
                if band % 3 == 0 {
                    var haze = context
                    haze.addFilter(.blur(radius: 2.4 * scale))
                    haze.opacity *= 0.35
                    haze.stroke(contour, with: shading, lineWidth: 4 * scale)
                }
                context.stroke(contour, with: shading,
                               style: StrokeStyle(lineWidth: 1.25 * scale, lineCap: .round))
            }
        }
    }

    private static func afterglowContour(width: Double, edgeY: Double, inward: Double,
                                          scale: Double, band: Int, edge: Int, time: Double) -> Path {
        let seed = Double(band)
        let direction = edge == 0 ? -1.0 : 1.0
        func sample(_ x: Double) -> (point: CGPoint, slope: Double) {
            // Two traveling scales carry broad sunset swells and smaller edge folds.
            // No modulo, reseeding, or energy-dependent geometry: phase survives pause.
            let swell = x * 0.022 - time * 88 * 0.022 * direction + seed * 0.19 + Double(edge)
            let fold = x * 0.051 - time * 56 * 0.051 * direction - seed * 0.23
            let depth = 6 + seed * 2.8 + 4.2 * sin(swell) + 1.5 * sin(fold)
            let derivative = 4.2 * 0.022 * cos(swell) + 1.5 * 0.051 * cos(fold)
            return (CGPoint(x: x, y: edgeY + inward * depth * scale), inward * derivative * scale)
        }
        // Analytic tangent-matched cubics keep spatial joins and time derivatives smooth.
        // Fixed overscan and 48 segments cover the rim without reset seams or growing work.
        let step = (width + 48) / 48
        var previous = sample(-24)
        var path = Path()
        path.move(to: previous.point)
        for segment in 1...48 {
            let next = sample(-24 + Double(segment) * step)
            path.addCurve(to: next.point,
                          control1: CGPoint(x: previous.point.x + step / 3,
                                            y: previous.point.y + previous.slope * step / 3),
                          control2: CGPoint(x: next.point.x - step / 3,
                                            y: next.point.y - next.slope * step / 3))
            previous = next
        }
        return path
    }

    private static func opalFlowingLenses(context: inout GraphicsContext, size: CGSize,
                                          time: Double, strength: Double) {
        let scale = min(1, size.height / 112)
        let pearl = Color(red: 1, green: 0.96, blue: 0.88)
        for edge in 0..<2 {
            var rim = context
            rim.translateBy(x: 0, y: edge == 0 ? 0 : size.height)
            rim.scaleBy(x: 1, y: edge == 0 ? scale : -scale)
            for index in 0..<7 {
                let seed = Double(index) * 1.37 + Double(edge) * 2.1
                let drift = time * 0.92 + seed
                let center = CGPoint(x: (Double(index) - 0.1) * size.width / 6 + 28 * sin(drift),
                                     y: 4 + 3 * sin(time * 1.03 + seed))
                let rx = 63 + 9 * sin(time * 0.77 + seed)
                let ry = 17 + 3 * sin(time * 1.2 + seed + 0.8)
                let warp = time * 0.83 + seed
                let hue = 0.49 + 0.32 * (0.5 + 0.5 * sin(time * 0.55 + seed))
                let cool = Color(hue: hue, saturation: 0.42, brightness: 1)
                let warm = Color(hue: 0.88 + 0.05 * sin(time * 0.61 + seed),
                                 saturation: 0.28, brightness: 1)
                var glass = rim
                glass.translateBy(x: center.x, y: center.y)
                let lens = opalLensContour(rx: rx, ry: ry, warp: warp, start: 0, sweep: 2 * .pi)
                let lightX = rx * 0.65 * sin(time * 1.16 + seed)
                let lightY = ry * 0.55 * cos(time * 0.94 + seed)
                // Closed, overlapping pearl cells stay within 30 points of each rim.
                // Their drifting silhouettes and moving interference bands never reset.
                glass.fill(lens, with: .linearGradient(Gradient(stops: [
                    .init(color: cool.opacity(strength * 0.08), location: 0),
                    .init(color: cool.opacity(strength * 0.32), location: 0.25),
                    .init(color: pearl.opacity(strength * 0.30), location: 0.48),
                    .init(color: warm.opacity(strength * 0.28), location: 0.67),
                    .init(color: cool.opacity(strength * 0.04), location: 1)
                ]), startPoint: CGPoint(x: lightX - rx, y: -ry),
                    endPoint: CGPoint(x: lightX + rx, y: ry)))
                var interior = glass
                interior.clip(to: lens)
                interior.fill(lens, with: .radialGradient(Gradient(colors: [
                    pearl.opacity(strength * 0.38), warm.opacity(strength * 0.14), .clear
                ]), center: CGPoint(x: lightX, y: lightY), startRadius: 0, endRadius: rx * 0.8))
                glass.stroke(lens, with: .linearGradient(Gradient(colors: [
                    cool.opacity(strength * 0.5), pearl.opacity(strength * 0.24), warm.opacity(strength * 0.6)
                ]), startPoint: CGPoint(x: -rx, y: -ry), endPoint: CGPoint(x: rx, y: ry)), lineWidth: 0.8)

                // Opposed caustics keep a traveling highlight on the visible half of
                // every cell, even while the other highlight crosses the outer clip.
                for highlight in 0..<2 {
                    let arc = opalLensContour(rx: rx, ry: ry, warp: warp,
                                              start: time * 1.12 + seed + Double(highlight) * .pi,
                                              sweep: 1.3)
                    let sheen = GraphicsContext.Shading.linearGradient(Gradient(colors: [
                        cool.opacity(strength * 0.35), pearl.opacity(strength * 0.88),
                        warm.opacity(strength * 0.45)
                    ]), startPoint: CGPoint(x: -rx, y: 0), endPoint: CGPoint(x: rx, y: 0))
                    var bloom = glass
                    bloom.addFilter(.blur(radius: 1.8))
                    bloom.stroke(arc, with: sheen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    glass.stroke(arc, with: sheen, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                }
            }
        }
    }

    private static func opalLensContour(rx: Double, ry: Double, warp: Double,
                                        start: Double, sweep: Double) -> Path {
        func sample(_ angle: Double) -> (point: CGPoint, tangent: CGPoint) {
            let x = rx * (cos(angle) + 0.10 * cos(2 * angle + warp))
            let y = ry * sin(angle) * (1 + 0.12 * cos(angle + warp))
            let dx = rx * (-sin(angle) - 0.20 * sin(2 * angle + warp))
            let dy = ry * (cos(angle) * (1 + 0.12 * cos(angle + warp))
                           - 0.12 * sin(angle) * sin(angle + warp))
            return (CGPoint(x: x, y: y), CGPoint(x: dx, y: dy))
        }
        // Analytic tangents keep both the deforming outline and its caustics smooth.
        // Fixed tessellation bounds work independently of playback duration.
        let step = sweep / 24
        var previous = sample(start)
        var path = Path()
        path.move(to: previous.point)
        for segment in 1...24 {
            let next = sample(start + Double(segment) * step)
            path.addCurve(to: next.point,
                          control1: CGPoint(x: previous.point.x + previous.tangent.x * step / 3,
                                            y: previous.point.y + previous.tangent.y * step / 3),
                          control2: CGPoint(x: next.point.x - next.tangent.x * step / 3,
                                            y: next.point.y - next.tangent.y * step / 3))
            previous = next
        }
        if sweep == 2 * .pi { path.closeSubpath() }
        return path
    }

    private static func eclipseOrbitalCorona(context: inout GraphicsContext, size: CGSize,
                                              time: Double, strength: Double, violet: Color) {
        let scale = min(1, size.height / 112)
        let pink = Color(red: 1, green: 0.38, blue: 0.72)
        let light = 0.24 + strength * 0.76
        for edge in 0..<2 {
            for satellite in 0..<3 {
                // Small eclipses sit ON the surface; broad, flattened orbits occupy
                // both rims without putting luminous fills behind the central labels.
                let center = CGPoint(x: size.width * (0.17 + Double(satellite) * 0.33 + Double(edge) * 0.025),
                                     y: edge == 0 ? 11 * scale : size.height - 11 * scale)
                let phase = Double(satellite) * 1.7 + Double(edge) * 0.9
                var halo = context
                halo.addFilter(.blur(radius: 2.5 * scale))
                for ring in 0..<2 {
                    let rx = size.width / 540 * (ring == 0 ? 55.0 : 73.0)
                    let ry = (ring == 0 ? 13.0 : 20.0) * scale
                    let orbit = Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry,
                                                       width: rx * 2, height: ry * 2))
                    let color = ring == 0 ? violet : pink
                    context.stroke(orbit, with: .color(color.opacity(0.12 + strength * 0.13)), lineWidth: 0.8)
                    let direction = (edge + ring) % 2 == 0 ? 1.0 : -1.0
                    let angle = phase + time * direction * (ring == 0 ? 0.85 : 0.61)
                    // Opposed arcs guarantee a visible moving sector even when the
                    // other sector passes beyond the rounded top/bottom clipping edge.
                    for sector in 0..<2 {
                        let arc = eclipseOrbitArc(center: center, rx: rx, ry: ry,
                                                  start: angle + Double(sector) * .pi, sweep: 1.75)
                        halo.stroke(arc, with: .color(color.opacity(light * 0.42)), lineWidth: 4)
                        context.stroke(arc, with: .color(color.opacity(light * (sector == 0 ? 0.92 : 0.65))),
                                       style: StrokeStyle(lineWidth: 1.45, lineCap: .round))
                    }
                }

                let radius = 12.0 * scale
                let corona = Path(ellipseIn: CGRect(x: center.x - radius * 1.6, y: center.y - radius * 1.6,
                                                    width: radius * 3.2, height: radius * 3.2))
                context.fill(corona, with: .radialGradient(Gradient(stops: [
                    .init(color: violet.opacity(0), location: 0),
                    .init(color: violet.opacity(0), location: 0.48),
                    .init(color: violet.opacity(light * 0.48), location: 0.66),
                    .init(color: pink.opacity(light * 0.14), location: 0.82),
                    .init(color: pink.opacity(0), location: 1)
                ]), center: center, startRadius: 0, endRadius: radius * 1.6))
                let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                  width: radius * 2, height: radius * 2))
                context.fill(disk, with: .color(Color(red: 0.022, green: 0.009, blue: 0.04)))
                context.stroke(disk, with: .color(violet.opacity(light * 0.45)), lineWidth: 0.8)
                for crescent in 0..<2 {
                    let arc = eclipseOrbitArc(center: center, rx: radius + 0.8, ry: radius + 0.8,
                                              start: phase - time * 0.72 + Double(crescent) * .pi, sweep: 2.0)
                    let color = crescent == 0 ? violet : pink
                    halo.stroke(arc, with: .color(color.opacity(light * 0.5)), lineWidth: 4)
                    context.stroke(arc, with: .color(color.opacity(light)),
                                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
            }
        }
    }

    private static func eclipseOrbitArc(center: CGPoint, rx: Double, ry: Double,
                                         start: Double, sweep: Double) -> Path {
        var arc = Path()
        arc.addArc(center: .zero, radius: 1, startAngle: .radians(start),
                   endAngle: .radians(start + sweep), clockwise: false)
        return arc.applying(CGAffineTransform(a: rx, b: 0, c: 0, d: ry, tx: center.x, ty: center.y))
    }

    private struct CircuitTraceSegment {
        let start: CGPoint
        let end: CGPoint
        let center: CGPoint?
        let radius: Double
        let angle: Double
        let sweep: Double

        var length: Double {
            center == nil ? hypot(end.x - start.x, end.y - start.y) : radius * abs(sweep)
        }

        func point(at fraction: Double) -> CGPoint {
            guard let center else {
                return CGPoint(x: start.x + (end.x - start.x) * fraction,
                               y: start.y + (end.y - start.y) * fraction)
            }
            let theta = angle + sweep * fraction
            return CGPoint(x: center.x + radius * cos(theta), y: center.y + radius * sin(theta))
        }

        func append(to path: inout Path, from: Double, to: Double) {
            if let center {
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(angle + sweep * from),
                            endAngle: .radians(angle + sweep * to), clockwise: sweep < 0)
            } else {
                path.addLine(to: point(at: to))
            }
        }
    }

    private static func circuitTrace(size: CGSize, lane: Int) -> [CircuitTraceSegment] {
        let scale = min(1, size.height / 112)
        let radius = 2.5 * scale
        let depth = 7 * scale
        let y = (4.0 + Double(lane) * 9) * scale
        let pitch = (size.width + 192) / 6
        var segments: [CircuitTraceSegment] = []
        var cursor = CGPoint(x: -96 + Double(lane) * 16, y: y)
        func line(_ x: Double, _ y: Double) {
            let end = CGPoint(x: x, y: y)
            segments.append(CircuitTraceSegment(start: cursor, end: end, center: nil,
                                                radius: 0, angle: 0, sweep: 0))
            cursor = end
        }
        func arc(_ x: Double, _ y: Double, _ angle: Double, _ sweep: Double) {
            let center = CGPoint(x: x, y: y)
            let end = CGPoint(x: x + radius * cos(angle + sweep),
                              y: y + radius * sin(angle + sweep))
            segments.append(CircuitTraceSegment(start: cursor, end: end, center: center,
                                                radius: radius, angle: angle, sweep: sweep))
            cursor = end
        }
        // Exact tangent quarter-circles: distance is measured on the wire, not its x axis.
        for cell in 0..<6 {
            let x = -96 + Double(lane) * 16 + Double(cell) * pitch
            let down = x + pitch * 0.25
            let up = x + pitch * 0.72
            line(down - radius, y)
            arc(down - radius, y + radius, -.pi / 2, .pi / 2)
            line(down, y + depth - radius)
            arc(down + radius, y + depth - radius, .pi, -.pi / 2)
            line(up - radius, y + depth)
            arc(up - radius, y + depth - radius, .pi / 2, -.pi / 2)
            line(up, y + radius)
            arc(up + radius, y + radius, .pi, .pi / 2)
            line(x + pitch, y)
        }
        return segments
    }

    private static func circuitTraceSlice(_ segments: [CircuitTraceSegment],
                                           from start: Double, to end: Double) -> Path {
        var path = Path()
        var offset = 0.0
        var started = false
        for segment in segments {
            let length = segment.length
            let lower = max(0, start - offset)
            let upper = min(length, end - offset)
            if upper > lower, length > 0 {
                if !started {
                    path.move(to: segment.point(at: lower / length))
                    started = true
                }
                segment.append(to: &path, from: lower / length, to: upper / length)
            }
            offset += length
            if offset >= end { break }
        }
        return path
    }

    private static func circuitContinuousSignals(context: inout GraphicsContext, size: CGSize,
                                                   time: Double, strength: Double) {
        let cyan = Color(red: 0.12, green: 0.86, blue: 1)
        for edge in 0..<2 {
            var board = context
            board.translateBy(x: 0, y: edge == 0 ? 0 : size.height)
            board.scaleBy(x: 1, y: edge == 0 ? 1 : -1)
            for lane in 0..<2 {
                let segments = circuitTrace(size: size, lane: lane)
                let length = segments.reduce(0) { $0 + $1.length }
                let trace = circuitTraceSlice(segments, from: 0, to: length)
                board.stroke(trace, with: .color(cyan.opacity(0.16 + strength * 0.18)),
                             style: StrokeStyle(lineWidth: 0.85, lineCap: .round, lineJoin: .round))
                let spacing = length / 10
                let packetLength = spacing * 1.55
                let speed = lane == 0 ? 38.0 : 29.0
                let direction = edge == 0 ? 1.0 : -1.0
                let travel = time * speed * direction + spacing * (Double(lane) * 0.5 + Double(edge) * 0.31)
                let remainder = travel.truncatingRemainder(dividingBy: spacing)
                let phase = remainder < 0 ? remainder + spacing : remainder
                var halo = board
                halo.addFilter(.blur(radius: 2))
                // An identical packet train spans the entire overscanned wire. At wrap,
                // only tile identity changes; incoming/outgoing tiles are off-canvas.
                for tile in -2...12 {
                    let head = Double(tile) * spacing + phase
                    let tail = head - packetLength
                    let packet = circuitTraceSlice(segments, from: tail, to: head)
                    halo.stroke(packet, with: .color(cyan.opacity(strength * 0.16)),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    // Nested rounded pulses overlap their neighbours, leaving no dark gaps.
                    for layer in 0..<4 {
                        let inset = Double(layer) * packetLength * 0.19
                        let signal = circuitTraceSlice(segments, from: tail + inset,
                                                       to: head - Double(layer) * 1.2)
                        board.stroke(signal, with: .color(cyan.opacity(strength * (0.12 + Double(layer) * 0.08))),
                                     style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                    }
                    let core = circuitTraceSlice(segments, from: head - 5, to: head - 1)
                    board.stroke(core, with: .color(Color.white.opacity(strength * 0.85)),
                                 style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                }
                // Small stationary solder pads anchor the moving signals in technical geometry.
                for cell in 0..<6 {
                    let x = -96 + Double(lane) * 16 + (Double(cell) + 0.48) * (size.width + 192) / 6
                    let y = (11.0 + Double(lane) * 9) * min(1, size.height / 112)
                    let pad = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                    board.stroke(pad, with: .color(cyan.opacity(0.24 + strength * 0.28)), lineWidth: 0.7)
                }
            }
        }
    }

    private static func halogenIncandescentChambers(context: inout GraphicsContext, size: CGSize,
                                                    time: Double, strength: Double) {
        let scale = min(1, size.height / 112)
        let tungsten = Color(red: 1, green: 0.39, blue: 0.055)
        let honey = Color(red: 1, green: 0.72, blue: 0.24)
        let hot = Color(red: 1, green: 0.94, blue: 0.71)
        for edge in 0..<2 {
            // Work in inward-facing coordinates: two sealed lamp chambers, not ribbons.
            // Nothing luminous extends more than 26 points into the control area.
            var chamber = context
            chamber.translateBy(x: 0, y: edge == 0 ? 0 : size.height)
            chamber.scaleBy(x: 1, y: edge == 0 ? scale : -scale)
            let housing = Path(roundedRect: CGRect(x: 15, y: -12, width: max(1, size.width - 30),
                                                   height: 38), cornerRadius: 17)
            chamber.clip(to: housing)
            chamber.fill(housing, with: .linearGradient(Gradient(stops: [
                .init(color: tungsten.opacity(0.12 + strength * 0.16), location: 0),
                .init(color: honey.opacity(0.08 + strength * 0.10), location: 0.48),
                .init(color: tungsten.opacity(0), location: 1)
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 26)))

            let phase = time * 0.62 + Double(edge) * 2.1
            let focus = size.width * (0.5 + 0.37 * sin(phase))
            let echo = size.width * (0.5 + 0.32 * sin(time * 0.43 + Double(edge) * 2.4 + 2))
            // Flattened radial light pools scan the reflector continuously; no wrap/reset.
            var reflector = chamber
            reflector.scaleBy(x: 1, y: 0.24)
            for pool in 0..<2 {
                let center = CGPoint(x: pool == 0 ? focus : echo, y: 38)
                let radius = pool == 0 ? 116.0 : 82.0
                reflector.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                       width: radius * 2, height: radius * 2)),
                               with: .radialGradient(Gradient(stops: [
                                .init(color: honey.opacity(strength * (pool == 0 ? 0.64 : 0.38)), location: 0),
                                .init(color: tungsten.opacity(strength * 0.28), location: 0.48),
                                .init(color: tungsten.opacity(0), location: 1)
                               ]), center: center, startRadius: 0, endRadius: radius))
            }

            let filament = halogenCoiledFilament(width: size.width)
            chamber.stroke(filament, with: .color(tungsten.opacity(0.22 + strength * 0.25)),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            let incandescence = GraphicsContext.Shading.radialGradient(Gradient(stops: [
                .init(color: hot.opacity(0.35 + strength * 0.65), location: 0),
                .init(color: honey.opacity(strength * 0.88), location: 0.32),
                .init(color: tungsten.opacity(strength * 0.35), location: 0.72),
                .init(color: tungsten.opacity(0), location: 1)
            ]), center: CGPoint(x: focus, y: 11), startRadius: 0, endRadius: 118)
            var bloom = chamber
            bloom.addFilter(.blur(radius: 3))
            bloom.stroke(filament, with: incandescence, lineWidth: 5)
            chamber.stroke(filament, with: incandescence,
                           style: StrokeStyle(lineWidth: 1.35, lineCap: .round))

            // A softly lit glass lip gives the warm chamber a physical boundary.
            var lip = Path()
            lip.move(to: CGPoint(x: 30, y: 22))
            lip.addQuadCurve(to: CGPoint(x: size.width - 30, y: 22),
                             control: CGPoint(x: size.width / 2, y: 27))
            chamber.stroke(lip, with: .radialGradient(Gradient(colors: [
                honey.opacity(strength * 0.45), tungsten.opacity(0.025)
            ]), center: CGPoint(x: echo, y: 22), startRadius: 0, endRadius: 150), lineWidth: 0.8)
        }
    }

    private static func halogenCoiledFilament(width: Double) -> Path {
        // Fixed-count overlapping elliptical turns evoke wound tungsten wire.
        // Geometry stays still while the incandescent hotspot travels along it.
        let pitch = max(1, width - 56) / 38
        var wire = Path()
        wire.move(to: CGPoint(x: 20, y: 12))
        wire.addLine(to: CGPoint(x: 28, y: 12))
        for turn in 0..<38 {
            let x = 28 + Double(turn) * pitch
            wire.addCurve(to: CGPoint(x: x + pitch * 0.48, y: 5),
                          control1: CGPoint(x: x - pitch * 0.42, y: 3),
                          control2: CGPoint(x: x + pitch * 0.30, y: 1))
            wire.addCurve(to: CGPoint(x: x + pitch, y: 12),
                          control1: CGPoint(x: x + pitch * 1.18, y: 19),
                          control2: CGPoint(x: x + pitch * 0.10, y: 22))
        }
        wire.addLine(to: CGPoint(x: width - 20, y: 12))
        return wire
    }

    private static func velvetTravelingSilk(context: inout GraphicsContext, size: CGSize,
                                             time: Double, strength: Double, rose: Color) {
        let scale = min(1, size.height / 112)
        for edge in 0..<2 {
            let y = edge == 0 ? 0.0 : size.height
            let inward = edge == 0 ? 1.0 : -1.0
            // Broad overlapping folds carry the light, rather than pulsing in place.
            // Their 34-point maximum depth leaves the black-cherry center quiet.
            for fold in 0..<2 {
                let rim = velvetScallopedRim(size: size, edge: edge, fold: fold, time: time)
                var fabric = rim
                fabric.addLine(to: CGPoint(x: size.width + 24, y: y))
                fabric.addLine(to: CGPoint(x: -24, y: y))
                fabric.closeSubpath()
                let color = fold == 0 ? rose : Color(red: 0.80, green: 0.27, blue: 0.49)
                context.fill(fabric, with: .linearGradient(Gradient(stops: [
                    .init(color: color.opacity(strength * 0.10), location: 0),
                    .init(color: color.opacity(strength * 0.28), location: 0.45),
                    .init(color: color.opacity(0), location: 1)
                ]), startPoint: CGPoint(x: 0, y: y),
                    endPoint: CGPoint(x: 0, y: y + inward * 38 * scale)))

                var sheen = context
                sheen.addFilter(.blur(radius: 3 * scale))
                sheen.stroke(rim, with: .color(color.opacity(strength * 0.42)), lineWidth: 6 * scale)
                context.stroke(rim, with: .color(rose.opacity(strength * 0.24)),
                               style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round))
            }
        }
    }

    private static func velvetScallopedRim(size: CGSize, edge: Int, fold: Int, time: Double) -> Path {
        let scale = min(1, size.height / 112)
        let inward = edge == 0 ? 1.0 : -1.0
        let edgeY = edge == 0 ? 0.0 : size.height
        let frequency = 2 * Double.pi / (fold == 0 ? 184.0 : 218.0)
        let speed = fold == 0 ? 48.0 : 36.0
        let phase = -time * speed * frequency * inward + Double(fold) * 1.9 + Double(edge) * 0.8
        let depth = fold == 0 ? 23.0 : 12.0
        let amplitude = fold == 0 ? 8.0 : 5.0
        func sample(_ x: Double) -> (point: CGPoint, slope: Double) {
            let angle = x * frequency + phase
            let offset = depth + amplitude * cos(angle) + 2.5 * cos(2 * angle + 0.4)
            let derivative = -frequency * (amplitude * sin(angle) + 5 * sin(2 * angle + 0.4))
            return (CGPoint(x: x, y: edgeY + inward * offset * scale), inward * derivative * scale)
        }

        // Matched analytic tangents keep the traveling scallops smooth at every join.
        // Fixed sampling and an overscan margin avoid tile resets or edge popping.
        let step = (size.width + 48) / 36
        var previous = sample(-24)
        var path = Path()
        path.move(to: previous.point)
        for segment in 1...36 {
            let next = sample(-24 + Double(segment) * step)
            path.addCurve(to: next.point,
                          control1: CGPoint(x: previous.point.x + step / 3,
                                            y: previous.point.y + previous.slope * step / 3),
                          control2: CGPoint(x: next.point.x - step / 3,
                                            y: next.point.y - next.slope * step / 3))
            previous = next
        }
        return path
    }

    private static func laserEdgeComposition(context: inout GraphicsContext, size: CGSize,
                                              time: Double, strength: Double, coral: Color) {
        let spacing = max(90, size.width / 3)
        let length = spacing * 1.85
        for edge in 0..<2 {
            let inward = edge == 0 ? 1.0 : -1.0
            for lane in 0..<2 {
                let color: Color = lane == 0 ? coral : .cyan
                let inset = 5.0 + Double(lane) * 7
                let y = edge == 0 ? inset : size.height - inset
                let direction = (edge + lane) % 2 == 0 ? 1.0 : -1.0
                let slope = (lane == 0 ? 1.0 : -1.0) * inward
                var rail = Path()
                rail.move(to: CGPoint(x: -12, y: y))
                rail.addLine(to: CGPoint(x: size.width + 12, y: y))
                context.stroke(rail, with: .color(color.opacity(strength * 0.30)), lineWidth: 0.7)

                let phase = (time * (lane == 0 ? 62 : 46)
                             + Double(edge) * spacing * 0.43
                             + Double(lane) * spacing * 0.5)
                    .truncatingRemainder(dividingBy: spacing)
                var halo = context
                halo.addFilter(.blur(radius: 2.5))
                // Identical, overlapping tiles exchange only beyond the canvas bounds.
                // Modulo changes tile identity, never the visible beam arrangement.
                for tile in -2...5 {
                    let head = Double(tile) * spacing + phase
                    let tail = head - length
                    let startX = direction > 0 ? tail : size.width - tail
                    let endX = direction > 0 ? head : size.width - head
                    guard max(startX, endX) >= -12,
                          min(startX, endX) <= size.width + 12 else { continue }
                    let start = CGPoint(x: startX, y: y + slope * 3)
                    let end = CGPoint(x: endX, y: y - slope * 3)
                    var beam = Path()
                    beam.move(to: start)
                    beam.addLine(to: end)
                    let light = Gradient(stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color.opacity(strength * 0.45), location: 0.22),
                        .init(color: color.opacity(strength * 0.85), location: 0.72),
                        .init(color: color.opacity(strength), location: 0.92),
                        .init(color: color.opacity(0), location: 1)
                    ])
                    let shading = GraphicsContext.Shading.linearGradient(light, startPoint: start, endPoint: end)
                    halo.stroke(beam, with: shading, lineWidth: 4)
                    context.stroke(beam, with: shading, lineWidth: 1.3)
                    context.stroke(beam, with: .linearGradient(Gradient(stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0), location: 0.72),
                        .init(color: .white.opacity(strength * 0.8), location: 0.92),
                        .init(color: .white.opacity(0), location: 1)
                    ]), startPoint: start, endPoint: end), lineWidth: 0.45)
                }
            }
        }
    }

    private static func wave(size: CGSize, base: Double, amplitude: Double,
                             frequency: Double, phase: Double) -> Path {
        var path = Path()
        for step in 0...90 {
            let x = Double(step) / 90 * size.width
            let point = CGPoint(x: x, y: base + sin(x * frequency + phase) * amplitude)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private static func glow(_ path: Path, context: inout GraphicsContext, color: Color,
                             width: Double, strength: Double) {
        var halo = context
        halo.addFilter(.blur(radius: 4))
        halo.stroke(path, with: .color(color.opacity(strength * 0.4)), lineWidth: width + 5)
        context.stroke(path, with: .color(color.opacity(strength)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
