import Combine
import Foundation
import SwiftUI

enum PlaybackLayout: String, CaseIterable, Identifiable {
    case square, bottomBar
    var id: String { rawValue }
    var title: String { self == .square ? "Square" : "Bottom Bar" }
    var size: NSSize {
        self == .square ? NSSize(width: 300, height: 300) : NSSize(width: 540, height: 112)
    }
}

enum BarStyle: String, CaseIterable, Identifiable {
    // Twenty selector tiles: nineteen concrete designs plus Rotation.
    case studio, neon, blueprint, ember, prism
    case aurora, laser, velvet, halogen, circuit
    case cascade, eclipse, opal, ribbon, afterglow
    case mosaic, solar, mercury, radar, rotation
    static var rotationThemes: [BarStyle] {
        [.studio, .aurora, .neon, .laser, .blueprint, .circuit, .ember,
         .afterglow, .prism, .opal, .velvet, .halogen, .cascade, .eclipse,
         .ribbon, .mosaic, .solar, .mercury, .radar]
    }
    var isRefreshed: Bool {
        switch self {
        case .aurora, .laser, .velvet, .halogen, .circuit, .cascade,
             .eclipse, .opal, .ribbon, .afterglow, .mosaic: return true
        default: return false
        }
    }
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    static func restored(_ rawValue: String?) -> BarStyle {
        if ["paper", "cassette", "botanical"].contains(rawValue ?? "") { return .mercury }
        switch rawValue {
        case "terminal": return .circuit
        case "deepSea": return .aurora
        case "magnetic": return .mosaic
        default: break
        }
        return rawValue.flatMap(BarStyle.init(rawValue:)) ?? .studio
    }
    var detail: String {
        switch self {
        case .studio: return "Midnight and mint, with an edge spectrum."
        case .neon: return "Electric pink and violet with glowing perimeter trails."
        case .mercury: return "Sculpted liquid silver, flowing reflections, and rippling quicksilver pools."
        case .blueprint: return "Drafting blue, technical gridwork, and oscilloscope traces along the edges."
        case .ember: return "Matte charcoal and copper, with gently rising glowing sparks."
        case .rotation: return "A new theme with each song. Surfaces dissolve gently while controls stay in place."
        case .prism: return "Frosted glass and iridescent edges, with ribbons of refracted light."
        case .solar: return "Obsidian and molten gold with curling plasma and a luminous corona."
        case .radar: return "Naval green with an upper acquisition trace, instrument scales, and a radar sweep."
        case .aurora: return "Ink blue with broad mint-and-violet curtains of light."
        case .laser: return "Near-black with continuous, overlapping coral and cyan laser trails."
        case .velvet: return "Black cherry with traveling rose silk folds and soft scalloped highlights."
        case .halogen: return "Warm graphite with coiled tungsten filaments and traveling incandescent hotspots."
        case .circuit: return "Petrol blue with connected cyan traces and smoothly flowing signal trains."
        case .cascade: return "Midnight cobalt with staggered ice-blue falling light bars."
        case .eclipse: return "Plum-black with dark eclipses, violet coronas, and counter-rotating orbital arcs."
        case .opal: return "Smoky indigo with flowing pastel lenses, moving caustics, and pearl highlights."
        case .ribbon: return "Aubergine with interlaced fuchsia and tangerine silk curves."
        case .afterglow: return "Burgundy with flowing sunset strata and a softer upper-edge echo."
        case .mosaic: return "Navy with folding jewel facets, traveling creases, and a shifting tessellation."
        }
    }
    var foreground: Color { .white }
    var background: Color {
        switch self {
        case .studio: return Color(red: 0.045, green: 0.065, blue: 0.09)
        case .neon: return Color(red: 0.10, green: 0.035, blue: 0.19)
        case .mercury, .rotation: return Color(red: 0.065, green: 0.075, blue: 0.095)
        case .blueprint: return Color(red: 0.035, green: 0.16, blue: 0.31)
        case .ember: return Color(red: 0.09, green: 0.065, blue: 0.055)
        case .prism: return Color(red: 0.15, green: 0.18, blue: 0.27)
        case .solar: return Color(red: 0.10, green: 0.045, blue: 0.018)
        case .radar: return Color(red: 0.025, green: 0.085, blue: 0.065)
        case .aurora: return Color(red: 0.035, green: 0.06, blue: 0.13)
        case .laser: return Color(red: 0.055, green: 0.035, blue: 0.09)
        case .velvet: return Color(red: 0.12, green: 0.035, blue: 0.085)
        case .halogen: return Color(red: 0.095, green: 0.075, blue: 0.045)
        case .circuit: return Color(red: 0.025, green: 0.10, blue: 0.14)
        case .cascade: return Color(red: 0.035, green: 0.07, blue: 0.19)
        case .eclipse: return Color(red: 0.075, green: 0.035, blue: 0.12)
        case .opal: return Color(red: 0.12, green: 0.13, blue: 0.21)
        case .ribbon: return Color(red: 0.13, green: 0.03, blue: 0.14)
        case .afterglow: return Color(red: 0.14, green: 0.045, blue: 0.075)
        case .mosaic: return Color(red: 0.035, green: 0.065, blue: 0.12)
        }
    }
    var accent: Color {
        switch self {
        case .studio: return .mint
        case .neon: return Color(red: 1, green: 0.30, blue: 0.72)
        case .mercury, .rotation: return Color(red: 0.84, green: 0.89, blue: 0.96)
        case .blueprint: return Color(red: 0.65, green: 0.88, blue: 1)
        case .ember: return Color(red: 0.95, green: 0.48, blue: 0.26)
        case .prism: return Color(red: 0.79, green: 0.78, blue: 1)
        case .solar: return Color(red: 1, green: 0.75, blue: 0.25)
        case .radar: return Color(red: 0.55, green: 0.95, blue: 0.44)
        case .aurora: return Color(red: 0.42, green: 1, blue: 0.80)
        case .laser: return Color(red: 1, green: 0.40, blue: 0.51)
        case .velvet: return Color(red: 1, green: 0.62, blue: 0.77)
        case .halogen: return Color(red: 1, green: 0.82, blue: 0.42)
        case .circuit: return Color(red: 0.25, green: 0.91, blue: 1)
        case .cascade: return Color(red: 0.47, green: 0.77, blue: 1)
        case .eclipse: return Color(red: 0.79, green: 0.57, blue: 1)
        case .opal: return Color(red: 0.79, green: 0.96, blue: 1)
        case .ribbon: return Color(red: 1, green: 0.45, blue: 0.76)
        case .afterglow: return Color(red: 1, green: 0.64, blue: 0.43)
        case .mosaic: return Color(red: 0.42, green: 0.91, blue: 0.93)
        }
    }
    var playForeground: Color { .black }
    var fontDesign: Font.Design {
        switch self {
        case .blueprint, .circuit, .radar: return .monospaced
        default: return .default
        }
    }
}

enum VisualizerMotion: String, CaseIterable, Identifiable {
    case off, gentle, lively
    static func restored(_ value: String?) -> VisualizerMotion {
        value.flatMap(VisualizerMotion.init(rawValue:)) ?? .lively
    }
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var speed: Double { self == .gentle ? 0.65 : 3.6 }
    var amplitude: Double { self == .gentle ? 12 : 36 }
}

class PlaybackAppearancePreferencesModel: ObservableObject {
    @Published var albumLighting: Bool {
        didSet { UserDefaults.standard.set(albumLighting, forKey: "playback.albumLighting") }
    }
    @Published var songEntrance: Bool {
        didSet { UserDefaults.standard.set(songEntrance, forKey: "playback.songEntrance") }
    }
    @Published var physicalInteraction: Bool {
        didSet { UserDefaults.standard.set(physicalInteraction, forKey: "playback.physicalInteraction") }
    }
    @Published var focusAnchor: FocusAnchor {
        didSet { UserDefaults.standard.set(focusAnchor.rawValue, forKey: "playback.focusAnchor") }
    }
    @Published var focusMode: Bool {
        didSet { UserDefaults.standard.set(focusMode, forKey: "playback.focusMode") }
    }
    @Published private(set) var rotationTheme: BarStyle = .studio
    @Published private(set) var observedTrackIdentity: PlaybackTrackIdentity?
    private var rotation = ThemeRotation()
    var effectiveBarStyle: BarStyle { barStyle == .rotation ? rotationTheme : barStyle }

    @Published private(set) var themeSelectionRevision: UInt = 0

    @Published var barStyle: BarStyle {
        didSet {
            themeSelectionRevision &+= 1
            if barStyle == .rotation {
                rotation.start(from: oldValue)
                rotationTheme = rotation.current
            }
            UserDefaults.standard.set(barStyle.rawValue, forKey: "playback.barStyle")
        }
    }

    func observeTrack(_ identity: PlaybackTrackIdentity?) {
        rotation.observe(identity, enabled: barStyle == .rotation)
        if rotationTheme != rotation.current { rotationTheme = rotation.current }
        if observedTrackIdentity != identity { observedTrackIdentity = identity }
    }
    @Published var visualizerMotion: VisualizerMotion {
        didSet { UserDefaults.standard.set(visualizerMotion.rawValue, forKey: "playback.visualizerMotion") }
    }

    @Published var layout: PlaybackLayout {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: "playback.layout") }
    }

    @Published var hoverTintColor: NSColor {
        didSet {
            if let data = try? NSKeyedArchiver.archivedData(
                withRootObject: hoverTintColor,
                requiringSecureCoding: false
            ) {
                UserDefaults.standard.set(
                    data,
                    forKey: "playback.hoverTintColor"
                )
            }
        }
    }

    @Published var blurIntensity: Double {
        didSet {
            UserDefaults.standard.set(
                blurIntensity,
                forKey: "playback.blurIntensity"
            )
        }
    }

    @Published var foregroundColor: ForegroundColorOption {
        didSet {
            UserDefaults.standard.set(
                foregroundColor.rawValue,
                forKey: "playback.foregroundColor"
            )
        }
    }

    @Published var hoverTintOpacity: Double {
        didSet {
            UserDefaults.standard.set(
                hoverTintOpacity,
                forKey: "playback.hoverTintOpacity"
            )
        }
    }

    @Published var likingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                likingEnabled,
                forKey: "playback.likingEnabled"
            )
        }
    }

    enum ForegroundColorOption: String, CaseIterable, Identifiable {
        case white, black
        var id: String { rawValue }
        var color: Color {
            self == .white ? .white : .black
        }
    }

    init() {
        let defaults = UserDefaults.standard
        albumLighting = defaults.object(forKey: "playback.albumLighting") as? Bool ?? true
        songEntrance = defaults.object(forKey: "playback.songEntrance") as? Bool ?? true
        physicalInteraction = defaults.object(forKey: "playback.physicalInteraction") as? Bool ?? true
        focusMode = defaults.object(forKey: "playback.focusMode") as? Bool ?? false
        focusAnchor = FocusAnchor(rawValue: defaults.string(forKey: "playback.focusAnchor") ?? "") ?? .automatic
        layout = PlaybackLayout(rawValue: defaults.string(forKey: "playback.layout") ?? "") ?? .square
        barStyle = BarStyle.restored(defaults.string(forKey: "playback.barStyle"))
        visualizerMotion = VisualizerMotion.restored(defaults.string(forKey: "playback.visualizerMotion"))

        if let data = defaults.data(forKey: "playback.hoverTintColor"),
            let color = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSColor.self,
                from: data
            )
        {
            hoverTintColor = color
        } else {
            hoverTintColor = .systemBlue
        }

        blurIntensity =
            defaults.object(forKey: "playback.blurIntensity") as? Double ?? 0.5

        if let rawValue = defaults.string(forKey: "playback.foregroundColor"),
            let fg = ForegroundColorOption(rawValue: rawValue)
        {
            foregroundColor = fg
        } else {
            foregroundColor = .white
        }

        hoverTintOpacity =
            defaults.object(forKey: "playback.hoverTintOpacity") as? Double
            ?? 0.3
        likingEnabled =
            defaults.object(forKey: "playback.likingEnabled") as? Bool ?? true
        defaults.set(barStyle.rawValue, forKey: "playback.barStyle")
        defaults.set(visualizerMotion.rawValue, forKey: "playback.visualizerMotion")
    }
}
