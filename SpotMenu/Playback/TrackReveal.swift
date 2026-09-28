import SwiftUI

/// Artwork and material form one immutable visual snapshot. Stable layer IDs keep
/// the outgoing material's motion driver alive throughout the reveal.
@MainActor
final class TrackReveal: ObservableObject {
    static let duration = 1.8
    struct Layer: Identifiable {
        let id = UUID()
        let style: BarStyle
        let artwork: ResolvedArtwork
    }
    @Published private(set) var layers: [Layer] = []
    @Published private(set) var progress: CGFloat = 1
    private var queued: Layer?
    private var task: Task<Void, Never>?

    func request(style: BarStyle, artwork: ResolvedArtwork, animated: Bool, interrupt: Bool = false) {
        let next = Layer(style: style, artwork: artwork)
        if interrupt {
            // A deliberate selection always wins over automatic track reveals.
            // Preserve the latest material's identity as the outgoing layer, but
            // discard its task and any queued tracks before starting a fresh wipe.
            stop()
            if animated && !layers.isEmpty { start(next); return }
        }
        if !animated || layers.isEmpty {
            task?.cancel(); task = nil; queued = nil
            if layers.count == 1, matches(layers[0], next) { return }
            withoutAnimation { layers = [next]; progress = 1 }
            return
        }
        if let current = layers.last, matches(current, next) {
            queued = nil
            return
        }
        if task != nil { queued = next; return }
        start(next)
    }

    private func matches(_ lhs: Layer, _ rhs: Layer) -> Bool {
        lhs.style == rhs.style && lhs.artwork.id == rhs.artwork.id
    }

    private func start(_ next: Layer) {
        withoutAnimation { layers.append(next); progress = 0 }
        task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 20_000_000)
                guard let self else { return }
                withAnimation(.easeInOut(duration: Self.duration)) { self.progress = 1 }
                try await Task.sleep(nanoseconds: UInt64(Self.duration * 1_000_000_000))
                self.layers.removeFirst(self.layers.count - 1)
                self.task = nil
                if let next = self.queued { self.queued = nil; self.start(next) }
            } catch { }
        }
    }

    func discardQueued() { queued = nil }

    func stop() {
        task?.cancel(); task = nil; queued = nil
        withoutAnimation {
            if let latest = layers.last { layers = [latest] }
            progress = 1
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}

/// The cover occupies the same coordinates as the bar's transparent artwork hit
/// target. Masking the whole layer makes the material and cover share one edge.
struct TrackRevealSurface: View {
    let style: BarStyle
    let selectionRevision: UInt
    let identity: PlaybackTrackIdentity?
    let themeReady: Bool
    @ObservedObject var artwork: ArtworkStore
    let isPlaying: Bool
    let motion: VisualizerMotion
    let albumLighting: Bool
    let pointer: UnitPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var reveal = TrackReveal()

    var body: some View {
        ZStack {
            if reveal.layers.isEmpty {
                BarThemeBackground(style: style, isPlaying: isPlaying, motion: motion)
            }
            ForEach(reveal.layers) { layer in
                BarThemeBackground(style: layer.style, isPlaying: isPlaying, motion: motion)
                    .overlay {
                        if albumLighting {
                            PaletteLighting(palette: layer.artwork.palette, pointer: pointer)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        ArtworkImage(image: layer.artwork.image)
                            .frame(width: 72, height: 72)
                            .background(layer.style.foreground.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .offset(x: 18, y: 26)
                    }
                    .mask(MaterialReveal(progress: layer.id == reveal.layers.last?.id ? reveal.progress : 1))
            }
            if reveal.layers.count > 1 {
                MaterialReveal(progress: reveal.progress, edgeOnly: true)
                    .stroke(style.accent.opacity(0.45), lineWidth: 3)
                    .blur(radius: 3)
                    .opacity(sin(Double(reveal.progress) * .pi))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { submit() }
        .onChange(of: artwork.resolved.id) { _ in submit() }
        .onChange(of: identity) { _ in submit() }
        .onChange(of: style) { _ in submit() }
        .onChange(of: selectionRevision) { _ in submit(interrupt: true) }
        .onChange(of: themeReady) { _ in submit() }
        .onChange(of: reduceMotion) { _ in submit() }
        .onChange(of: motion) { _ in submit() }
        .onDisappear { reveal.stop() }
    }

    private func submit(interrupt: Bool = false) {
        if interrupt {
            // Manual choices must not wait for an unrelated artwork download.
            // Use the visible cover until the pending track's snapshot is ready.
            let snapshot = artwork.resolved.identity == identity
                ? artwork.resolved : (reveal.layers.last?.artwork ?? artwork.resolved)
            reveal.request(style: style, artwork: snapshot,
                           animated: !reduceMotion && motion != .off, interrupt: true)
            return
        }
        // Keep the old pair intact while the next cover is downloading. Failed or
        // absent art resolves to a placeholder, never an unbounded loading state.
        if reduceMotion || motion == .off { reveal.stop() }
        guard themeReady, artwork.resolved.identity == identity else {
            reveal.discardQueued()
            return
        }
        reveal.request(style: style, artwork: artwork.resolved,
                       animated: !reduceMotion && motion != .off)
    }
}
