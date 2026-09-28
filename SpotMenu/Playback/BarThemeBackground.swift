import SwiftUI

/// A self-contained, noninteractive layer. Rotation dissolves only these surfaces,
/// never duplicates the player controls or moves the album artwork.
struct BarThemeBackground: View {
    let style: BarStyle
    let isPlaying: Bool
    let motion: VisualizerMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(style.background.opacity(style == .prism ? 0.65 : 1))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                if style == .solar {
                    // A single plasma layer: don't superimpose static and animated strands.
                    SolarSurface(isPlaying: isPlaying, motion: motion)
                } else if style == .mercury {
                    MercurySurface(isPlaying: isPlaying, motion: motion)
                } else if style.isRefreshed {
                    RefreshedThemeSurface(style: style, isPlaying: isPlaying, motion: motion)
                } else {
                    BarThemeSurface(style: style)
                    if style == .neon {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(colors: [.purple.opacity(0.35), .clear, .pink.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    if motion == .lively {
                        LivelyBarEffects(style: style, isPlaying: isPlaying)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(style == .neon ? style.accent.opacity(0.5) : style.foreground.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
