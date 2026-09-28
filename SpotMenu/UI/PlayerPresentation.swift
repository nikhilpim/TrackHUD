import SwiftUI

final class PlayerPresentation: ObservableObject {
    @Published var compact = false
    @Published var visible = false
    @Published var anchor: FocusAnchor = .bottomLeft
    var hoverChanged: (Bool) -> Void = { _ in }
    var dragChanged: (Bool) -> Void = { _ in }
    var expand: () -> Void = {}
}

enum FocusAnchor: String, CaseIterable, Identifiable {
    case automatic, bottomLeft, bottomRight, topLeft, topRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic (nearest corner)"
        case .bottomLeft: return "Bottom Left — expand right & up"
        case .bottomRight: return "Bottom Right — expand left & up"
        case .topLeft: return "Top Left — expand right & down"
        case .topRight: return "Top Right — expand left & down"
        }
    }
    var isRight: Bool { self == .bottomRight || self == .topRight }
    var isTop: Bool { self == .topLeft || self == .topRight }
    var alignment: Alignment {
        switch self {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomRight: return .bottomTrailing
        default: return .bottomLeading
        }
    }
    func resolved(for frame: NSRect, in bounds: NSRect) -> FocusAnchor {
        guard self == .automatic else { return self }
        let right = frame.midX >= bounds.midX
        let top = frame.midY >= bounds.midY
        return top ? (right ? .topRight : .topLeft) : (right ? .bottomRight : .bottomLeft)
    }
}

enum FocusGeometry {
    static let compactSize = NSSize(width: 84, height: 84)

    static func clamped(_ frame: NSRect, to bounds: NSRect) -> NSRect {
        NSRect(x: max(bounds.minX, min(frame.minX, bounds.maxX - frame.width)),
               y: max(bounds.minY, min(frame.minY, bounds.maxY - frame.height)),
               width: frame.width, height: frame.height)
    }
    static func expanded(from compact: NSRect, in bounds: NSRect, anchor: FocusAnchor = .automatic) -> NSRect {
        let anchor = anchor.resolved(for: compact, in: bounds)
        return clamped(NSRect(x: anchor.isRight ? compact.maxX - 540 : compact.minX,
                              y: anchor.isTop ? compact.maxY - 112 : compact.minY,
                              width: 540, height: 112), to: bounds)
    }
    static func collapsed(from expanded: NSRect, in bounds: NSRect, anchor: FocusAnchor = .automatic) -> NSRect {
        let anchor = anchor.resolved(for: expanded, in: bounds)
        return clamped(NSRect(x: anchor.isRight ? expanded.maxX - compactSize.width : expanded.minX,
                              y: anchor.isTop ? expanded.maxY - compactSize.height : expanded.minY,
                              width: compactSize.width, height: compactSize.height), to: bounds)
    }
}

struct FloatingPlayerRoot: View {
    @ObservedObject var model: PlaybackModel
    @ObservedObject var preferences: PlaybackAppearancePreferencesModel
    @ObservedObject var musicPreferences: MusicPlayerPreferencesModel
    @ObservedObject var presentation: PlayerPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { _ in
            Group {
                if presentation.visible {
                    if presentation.compact {
                        focusJewel.transition(.opacity)
                    } else {
                        PlaybackView(model: model, preferences: preferences, musicPlayerPreferencesModel: musicPreferences,
                                     onDragChanged: presentation.dragChanged)
                            .transition(.opacity)
                    }
                } else { Color.clear }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: presentation.anchor.alignment)
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: presentation.compact)
        .onHover { presentation.hoverChanged($0) }
    }

    private var focusJewel: some View {
        ZStack(alignment: .top) {
            Button(action: presentation.expand) {
                AlbumArtwork(store: model.artwork)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: model.isPlaying ? "play.fill" : "pause.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(.black.opacity(0.65), in: Circle())
                            .padding(4)
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 22).fill(preferences.effectiveBarStyle.background)
                            .overlay {
                                if preferences.albumLighting { AlbumLighting(artwork: model.artwork).clipShape(RoundedRectangle(cornerRadius: 22)) }
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22).strokeBorder(preferences.effectiveBarStyle.accent.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expand music player. \(model.title)")
            .help("Hover to unfold • Click to expand")
            PlayerDragHandle(onDragChanged: presentation.dragChanged)
                .frame(width: 60, height: 10)
                .help("Drag to move player")
        }
        .frame(width: 84, height: 84)
    }
}
