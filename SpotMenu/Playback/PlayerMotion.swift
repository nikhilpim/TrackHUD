import SwiftUI

/// Shared geometry for the material mask and its luminous liquid boundary.
struct MaterialReveal: Shape {
    var progress: CGFloat
    var edgeOnly = false
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    static func boundary(progress: CGFloat, y: CGFloat, size: CGSize) -> CGFloat {
        let p = max(0, min(1, progress))
        return -48 + (size.width + 96) * p
            + sin(y / max(1, size.height) * .pi * 2 + p * .pi) * 22 * sin(p * .pi)
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if !edgeOnly { path.move(to: CGPoint(x: rect.minX, y: rect.minY)) }
        for step in 0...48 {
            let y = CGFloat(step) / 48 * rect.height
            let point = CGPoint(x: rect.minX + Self.boundary(progress: progress, y: y, size: rect.size), y: rect.minY + y)
            if edgeOnly && step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if !edgeOnly {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// At most two materials run during the reveal. Rapid song skips queue only the
/// latest theme, so transitions never stack an unbounded number of renderers.
struct TransformingMaterial: View, Equatable {
    // Parent metadata/seek/hover updates are not inputs to the material clock.
    // Local transition state and accessibility environment still update normally.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.style == rhs.style && lhs.isPlaying == rhs.isPlaying && lhs.motion == rhs.motion
    }

    let style: BarStyle
    let isPlaying: Bool
    let motion: VisualizerMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active: BarStyle?
    @State private var previous: BarStyle?
    @State private var queued: BarStyle?
    @State private var progress: CGFloat = 1
    @State private var transitionTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let previous { BarThemeBackground(style: previous, isPlaying: isPlaying, motion: motion) }
            BarThemeBackground(style: active ?? style, isPlaying: isPlaying, motion: motion)
                .mask(MaterialReveal(progress: progress))
            if previous != nil {
                MaterialReveal(progress: progress, edgeOnly: true)
                    .stroke((active ?? style).accent.opacity(0.45), lineWidth: 3)
                    .blur(radius: 3)
                    .opacity(sin(Double(progress) * .pi))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { active = style; progress = 1 }
        .onChange(of: style) { next in request(next) }
        .onChange(of: reduceMotion) { _ in request(style) }
        .onChange(of: motion) { _ in if motion == .off { request(style) } }
        .onDisappear {
            transitionTask?.cancel(); transitionTask = nil
            active = style; previous = nil; queued = nil; progress = 1
        }
    }

    private func request(_ next: BarStyle) {
        if reduceMotion || motion == .off {
            transitionTask?.cancel(); transitionTask = nil
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { active = next; previous = nil; queued = nil; progress = 1 }
            return
        }
        if transitionTask != nil { queued = next; return }
        guard let current = active, current != next else { active = next; return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { previous = current; active = next; progress = 0 }
        transitionTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 20_000_000)
                withAnimation(.easeInOut(duration: 1.35)) { progress = 1 }
                try await Task.sleep(nanoseconds: 1_400_000_000)
                previous = nil
                transitionTask = nil
                if let next = queued { queued = nil; request(next) }
            } catch { }
        }
    }
}

struct PlayerResponseOverlay: View {
    let pointer: UnitPoint
    let hovering: Bool
    let rippleOrigin: CGPoint
    let ripple: CGFloat
    let entrance: CGFloat
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(colors: [.white.opacity(hovering ? 0.10 : 0), .clear], center: pointer,
                               startRadius: 0, endRadius: 130)
                Circle().stroke(accent.opacity(Double(1 - ripple) * 0.45), lineWidth: 1.2)
                    .frame(width: 320 * ripple, height: 320 * ripple)
                    .position(rippleOrigin)
                // One restrained wave on song entry, not a repeating shimmer.
                LinearGradient(colors: [.clear, accent.opacity(0.16 * sin(Double(entrance) * .pi)), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90)
                    .offset(x: -geometry.size.width / 2 - 60 + (geometry.size.width + 120) * entrance)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
