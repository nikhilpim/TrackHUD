import AppKit
import SwiftUI

struct PlaybackView: View {
    @ObservedObject var model: PlaybackModel
    @ObservedObject var preferences: PlaybackAppearancePreferencesModel
    @ObservedObject var musicPlayerPreferencesModel: MusicPlayerPreferencesModel
    var onDragChanged: (Bool) -> Void = { _ in }
    @State private var isHovering = false
    @State private var pointer: UnitPoint = .center
    @State private var barHovered = false
    @State private var entrance: CGFloat = 1
    @State private var hasObservedTrack = false
    @State private var ripple: CGFloat = 1
    @State private var rippleOrigin = CGPoint.zero
    @State private var rippleTask: Task<Void, Never>?
    @State private var dragging = false
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if preferences.layout == .bottomBar {
                bottomBar
            } else {
                squarePlayer
            }
        }
    }

    private var squarePlayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(width: 300, height: 300)

            content
                .clipShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .frame(width: 300, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) {
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.8))
                    .frame(width: 32, height: 4)
                    .shadow(radius: 2)
                PlayerDragHandle(onDragChanged: onDragChanged)
            }
            .frame(width: 80, height: 24)
            .help("Drag to move player • Click the menu-bar item to hide")
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    private var barStyle: BarStyle { preferences.effectiveBarStyle }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            // Artwork is rendered with the material behind this stable hit target.
            Color.clear
            .frame(width: 72, height: 72)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { model.openMusicApp() }
            .help("Open music app")

            VStack(alignment: .leading, spacing: 6) {
                Text(model.title.isEmpty ? "Nothing playing" : model.title)
                    .font(.system(size: 13, weight: .semibold, design: barStyle.fontDesign))
                    .lineLimit(1)
                Text(model.artist.isEmpty ? "SpotMenu" : model.artist)
                    .font(.system(size: 11, design: barStyle.fontDesign))
                    .foregroundStyle(barStyle.foreground.opacity(0.6))
                    .lineLimit(1)
                PlaybackProgressControls(
                    progress: model.progress,
                    foregroundColor: barStyle.accent,
                    trackColor: barStyle.foreground.opacity(0.16),
                    seek: model.updatePlaybackPosition
                )
                .frame(height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0.65 + entrance * 0.35)
            .offset(y: (1 - entrance) * 4)

            HStack(spacing: 8) {
                barButton("backward.fill", label: "Previous track", action: model.skipBack)
                Button(action: model.togglePlayPause) {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(barStyle.playForeground)
                        .frame(width: 38, height: 38)
                        .background(barStyle.accent, in: Circle())
                        .shadow(color: barStyle == .neon ? barStyle.accent.opacity(0.5) : .clear, radius: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                barButton("forward.fill", label: "Next track", action: model.skipForward)
            }

            Group {
                if preferences.visualizerMotion == .off {
                    VStack(spacing: 5) {
                        Image(systemName: "headphones")
                            .font(.system(size: 16, weight: .light))
                        Text("SPOTMENU")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(barStyle.foreground.opacity(0.35))
                    .accessibilityHidden(true)
                } else {
                    PlaybackVisualizer(isPlaying: model.isPlaying, motion: preferences.visualizerMotion, style: barStyle)
                        .equatable()
                        .help("Decorative playback animation")
                }
            }
            .frame(width: 58, height: 44)

            barButton("gearshape", label: "Preferences") {
                NSApp.sendAction(#selector(AppDelegate.preferencesAction), to: nil, from: nil)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .frame(width: 540, height: 112)
        .foregroundStyle(barStyle.foreground)
        .background {
            TrackRevealSurface(style: barStyle, selectionRevision: preferences.themeSelectionRevision,
                               identity: model.trackIdentity,
                               themeReady: preferences.barStyle != .rotation || preferences.observedTrackIdentity == model.trackIdentity,
                               artwork: model.artwork,
                               isPlaying: model.isPlaying, motion: preferences.visualizerMotion,
                               albumLighting: preferences.albumLighting,
                               pointer: interactionsEnabled ? pointer : .center)
                .offset(x: interactionsEnabled && dragging ? 2 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: dragging)
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .overlay(alignment: .top) {
            ZStack {
                Capsule().fill(barStyle.foreground.opacity(0.3)).frame(width: 36, height: 3)
                PlayerDragHandle(onDragChanged: { dragging = $0; onDragChanged($0) })
            }
            .frame(width: 100, height: 20)
            .help("Drag to move player")
        }
        .overlay {
            PlayerResponseOverlay(pointer: pointer, hovering: interactionsEnabled && barHovered,
                                  rippleOrigin: rippleOrigin, ripple: ripple, entrance: entrance, accent: barStyle.accent)
        }
        .onContinuousHover { phase in
            guard interactionsEnabled else { return }
            switch phase {
            case .active(let location):
                barHovered = true
                pointer = UnitPoint(x: min(1, max(0, location.x / 540)), y: min(1, max(0, location.y / 112)))
            case .ended:
                barHovered = false
                withAnimation(.easeOut(duration: 0.4)) { pointer = .center }
            }
        }
        .simultaneousGesture(SpatialTapGesture().onEnded { event in
            guard interactionsEnabled else { return }
            rippleTask?.cancel()
            rippleOrigin = event.location
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { ripple = 0 }
            rippleTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 20_000_000)
                    withAnimation(.easeOut(duration: 0.6)) { ripple = 1 }
                } catch { }
            }
        })
        .task(id: model.trackIdentity) {
            preferences.observeTrack(model.trackIdentity)
            if !hasObservedTrack { hasObservedTrack = true; return }
            // Rotation uses the coordinated cover/material wipe, not a separate
            // entrance pulse that makes the outgoing theme look like it reloads.
            guard preferences.barStyle != .rotation,
                  model.trackIdentity != nil, preferences.songEntrance,
                  !reduceMotion, preferences.visualizerMotion != .off else { entrance = 1; return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { entrance = 0 }
            do {
                try await Task.sleep(nanoseconds: 20_000_000)
                withAnimation(.easeOut(duration: 0.85)) { entrance = 1 }
            } catch { }
        }
        .onChange(of: reduceMotion) { enabled in
            if enabled { rippleTask?.cancel(); ripple = 1; entrance = 1; barHovered = false; pointer = .center }
        }
        .onChange(of: preferences.visualizerMotion) { motion in
            if motion == .off { rippleTask?.cancel(); ripple = 1; entrance = 1; barHovered = false; pointer = .center }
        }
        .onDisappear { rippleTask?.cancel(); ripple = 1 }
        .animation(themeTransition, value: barStyle)
    }

    private var interactionsEnabled: Bool {
        preferences.physicalInteraction && !reduceMotion && preferences.visualizerMotion != .off
    }

    private var themeTransition: Animation? {
        reduceMotion || preferences.visualizerMotion == .off ? nil : .easeInOut(duration: TrackReveal.duration)
    }

    private func barButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var content: some View {
        let blurRadius = isHovering ? preferences.blurIntensity * 10 : 0
        let overlayColor =
            isHovering
            ? adaptiveHoverTintColor.opacity(preferences.hoverTintOpacity)
            : nil

        AlbumArtwork(store: model.artwork)
            .frame(width: 300, height: 300)
            .clipped()
            .blur(radius: blurRadius)
            .overlay(overlayColor)

        if isHovering {
            controlsOverlay
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: model.openMusicApp) {
                    Image(model.playerIconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(preferences.foregroundColor.color)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    NSApp.sendAction(
                        #selector(AppDelegate.preferencesAction),
                        to: nil,
                        from: nil
                    )
                }) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(preferences.foregroundColor.color)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .leading, .trailing], 16)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                Text(model.artist)
                    .font(.title3)
                    .foregroundColor(preferences.foregroundColor.color)
                    .lineLimit(2)
                    .padding(.horizontal)

                HStack(spacing: 10) {
                    tappableIconButton(
                        imageName: "backward.fill",
                        imageSize: 30
                    ) {
                        model.skipBack()
                    }

                    tappableIconButton(
                        imageName: model.isPlaying ? "pause.fill" : "play.fill",
                        imageSize: 40
                    ) {
                        model.togglePlayPause()
                    }

                    tappableIconButton(imageName: "forward.fill", imageSize: 30)
                    {
                        model.skipForward()
                    }
                }
                .foregroundColor(preferences.foregroundColor.color)

                Text(model.title)
                    .font(.title3)
                    .foregroundColor(preferences.foregroundColor.color)
                    .lineLimit(2)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)

            HStack(alignment: .center) {

                PlaybackProgressControls(
                    progress: model.progress,
                    foregroundColor: preferences.foregroundColor.color,
                    trackColor: preferences.foregroundColor.color,
                    showsTimes: true,
                    seek: model.updatePlaybackPosition
                )

                if model.isLikingImplemented
                    && musicPlayerPreferencesModel.likingEnabled
                {
                    Group {
                        if let isLiked = model.isLiked {
                            Button(action: {
                                model.toggleLiked()
                            }) {
                                Image(
                                    systemName: isLiked ? "heart.fill" : "heart"
                                )
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(
                                    preferences.foregroundColor.color
                                )
                                .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle like status")
                        } else {
                            Button(action: {
                                model.toggleLiked()  // triggers login
                            }) {
                                Image(systemName: "heart")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(
                                        preferences.foregroundColor.color
                                            .opacity(0.3)
                                    )
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Login to enable liking tracks")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

        }
        .padding(.horizontal)
        .transition(.opacity)
    }

    private var adaptiveHoverTintColor: Color {
        return Color(preferences.hoverTintColor)
    }
}

struct PlaybackVisualizer: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isPlaying == rhs.isPlaying && lhs.motion == rhs.motion && lhs.style == rhs.style
    }

    let isPlaying: Bool
    let motion: VisualizerMotion
    let style: BarStyle

    var body: some View {
        PlaybackMotionSurface(isPlaying: isPlaying, enabled: motion != .off) { time, energy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<9) { index in
                    let wave = (sin(time * motion.speed + Double(index) * 0.85)
                        + sin(time * motion.speed * 0.58 + Double(index) * 1.7) + 2) / 4
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [style.accent, style.accent.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 6 + motion.amplitude * wave * energy)
                        .opacity(motion == .gentle ? 0.55 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Motion samples are already animation frames. Never interpolate
            // them using an inherited seek/hover/theme animation transaction.
            .transaction { $0.animation = nil }
        }
        .accessibilityHidden(true)
    }
}

// A dedicated drag region keeps playback buttons and the seek slider independent.
struct PlayerDragHandle: NSViewRepresentable {
    var onDragChanged: (Bool) -> Void = { _ in }
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) { nsView.onDragChanged = onDragChanged }

    final class DragView: NSView {
        var onDragChanged: (Bool) -> Void = { _ in }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            guard let panel = window as? PopoverWindow else { return }
            onDragChanged(true)
            panel.performDrag(with: event)
            onDragChanged(false)
        }
    }
}

#Preview {
    let model = PlaybackModel(preferences: MusicPlayerPreferencesModel())
    model.imageURL = URL(
        string:
            "https://i.scdn.co/image/ab67616d0000b27377054612c5275c1515b18a50"
    )
    model.artist = "The Weeknd"
    return PlaybackView(
        model: model,
        preferences: PlaybackAppearancePreferencesModel(),
        musicPlayerPreferencesModel: MusicPlayerPreferencesModel()
    )
}

@ViewBuilder
func tappableIconButton(
    imageName: String,
    imageSize: CGFloat,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Image(systemName: imageName)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize, height: imageSize)
            .padding(30)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}
