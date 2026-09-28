import Testing
import SwiftUI
@testable import SpotMenu

struct SpotMenuTests {

    @Test func barDesignsHaveStableUniqueIdentifiers() {
        #expect(BarStyle.allCases.count == 20)
        #expect(Set(BarStyle.allCases.map(\.rawValue)).count == 20)
        for style in BarStyle.allCases {
            #expect(BarStyle(rawValue: style.rawValue) == style)
            #expect(!style.detail.isEmpty)
        }
        #expect(BarStyle.rotationThemes.count == 19)
        #expect(Set(BarStyle.rotationThemes) == Set(BarStyle.allCases.filter { $0 != .rotation }))
        for favorite in [BarStyle.studio, .neon, .blueprint, .ember, .prism] {
            #expect(BarStyle.allCases.contains(favorite))
        }
    }

    @Test func retiredThemesMigrateWithoutLosingOtherSelections() {
        #expect(BarStyle(rawValue: "focus") == nil)
        #expect(BarStyle(rawValue: "paper") == nil)
        #expect(BarStyle.restored("focus") == .studio)
        #expect(BarStyle.restored("paper") == .mercury)
        #expect(BarStyle(rawValue: "cassette") == nil)
        #expect(BarStyle(rawValue: "botanical") == nil)
        #expect(BarStyle.restored("cassette") == .mercury)
        #expect(BarStyle.restored("botanical") == .mercury)
        #expect(BarStyle.restored(nil) == .studio)
        #expect(BarStyle(rawValue: "terminal") == nil)
        #expect(BarStyle(rawValue: "deepSea") == nil)
        #expect(BarStyle(rawValue: "magnetic") == nil)
        #expect(BarStyle.restored("terminal") == .circuit)
        #expect(BarStyle.restored("deepSea") == .aurora)
        #expect(BarStyle.restored("magnetic") == .mosaic)
        for style in BarStyle.allCases { #expect(BarStyle.restored(style.rawValue) == style) }
    }

    @Test @MainActor func allThemeArtworkRenders() {
        for style in BarStyle.allCases {
            let surface = ImageRenderer(content: BarThemeSurface(style: style).frame(width: 540, height: 112))
            #expect(surface.nsImage != nil)
            let effect = ImageRenderer(content: LivelyBarEffects(style: style, isPlaying: false)
                .frame(width: 540, height: 112))
            #expect(effect.nsImage != nil)
        }
        for motion in VisualizerMotion.allCases {
            let mercury = ImageRenderer(content: MercurySurface(isPlaying: false, motion: motion).frame(width: 540, height: 112))
            #expect(mercury.nsImage != nil)
        }
        for style in BarStyle.rotationThemes {
            let background = ImageRenderer(content: BarThemeBackground(style: style, isPlaying: false, motion: .lively).frame(width: 540, height: 112))
            #expect(background.nsImage != nil)
        }
    }

    @Test @MainActor func refreshedThemesHaveDistinctMovingAndRestingFrames() throws {
        func pixels(style: BarStyle, time: Double, energy: Double) throws -> Data {
            let renderer = ImageRenderer(content: Canvas { context, size in
                RefreshedThemeEffects.draw(style, context: &context, size: size, time: time, energy: energy)
            }.frame(width: 540, height: 112))
            let image = try #require(renderer.cgImage)
            return try #require(image.dataProvider?.data) as Data
        }
        var restingFrames = Set<Data>()
        let themes = BarStyle.allCases.filter(\.isRefreshed)
        #expect(themes.count == 11)
        for style in themes {
            let resting = try pixels(style: style, time: 0, energy: 0)
            #expect(resting == (try pixels(style: style, time: 0, energy: 0)))
            restingFrames.insert(resting)
            let playing = try pixels(style: style, time: 0, energy: 1)
            #expect(playing != resting)
            #expect(playing != (try pixels(style: style, time: 1, energy: 1)))
        }
        #expect(restingFrames.count == themes.count)
    }

    @Test func rotationChangesOnlyForNewTracks() {
        var rotation = ThemeRotation()
        let first = PlaybackTrackIdentity(player: "spotify", trackID: "one", artist: "Artist", title: "First")
        rotation.observe(first, enabled: true)
        #expect(rotation.current == .studio)
        rotation.observe(nil, enabled: true)
        rotation.observe(first, enabled: true)
        #expect(rotation.current == .studio)
        // Updated labels and album artwork do not alter a native track identity.
        let refreshed = PlaybackTrackIdentity(player: "spotify", trackID: "one", artist: "New metadata", title: "Edited")
        #expect(first == refreshed)
        rotation.observe(refreshed, enabled: true)
        #expect(rotation.current == .studio)
        let second = PlaybackTrackIdentity(player: "spotify", trackID: "two", artist: "Artist", title: "First")
        rotation.observe(second, enabled: true)
        #expect(rotation.current == .aurora)
        rotation.observe(first, enabled: false)
        #expect(rotation.current == .aurora)
        rotation.start(from: .ember)
        rotation.observe(first, enabled: true)
        #expect(rotation.current == .ember)
        rotation.observe(second, enabled: true)
        #expect(rotation.current == .afterglow)
    }

    @Test func rotationVisitsEveryConcreteThemeWithoutRepeats() {
        var rotation = ThemeRotation()
        var visited: [BarStyle] = []
        for index in 0..<BarStyle.rotationThemes.count {
            rotation.observe(PlaybackTrackIdentity(player: "music", trackID: "\(index)", artist: "", title: ""), enabled: true)
            visited.append(rotation.current)
        }
        #expect(Set(visited) == Set(BarStyle.rotationThemes))
        #expect(!visited.contains(.rotation))
        rotation.observe(PlaybackTrackIdentity(player: "music", trackID: "\(BarStyle.rotationThemes.count)", artist: "", title: ""), enabled: true)
        #expect(rotation.current == .studio)
    }

    @Test func fallbackTrackIdentityDistinguishesArtistsAndPlayers() {
        let first = PlaybackTrackIdentity(player: "spotify", trackID: nil, artist: "AB", title: "C")
        #expect(first != PlaybackTrackIdentity(player: "spotify", trackID: nil, artist: "A", title: "BC"))
        #expect(first != PlaybackTrackIdentity(player: "music", trackID: nil, artist: "AB", title: "C"))
    }

    @Test func gentleMotionIsLessDistracting() {
        #expect(VisualizerMotion.gentle.speed < VisualizerMotion.lively.speed)
        #expect(VisualizerMotion.gentle.amplitude < VisualizerMotion.lively.amplitude)
        #expect(VisualizerMotion(rawValue: "off") == .off)
    }

    @Test func retiredReactiveModeMigratesToDecorativeMotion() {
        #expect(VisualizerMotion(rawValue: "reactive") == nil)
        #expect(VisualizerMotion.restored("reactive") == .lively)
        #expect(VisualizerMotion.allCases.count == 3)
    }

    @Test @MainActor func menuBarLogoIsCompactAndAdaptsToAppearance() {
        #expect(SpotMenuLogo.image.isTemplate)
        #expect(SpotMenuLogo.image.size.width == 18)
        #expect(SpotMenuLogo.image.size.height == 18)
    }

    @Test func barKeepsItsOriginalDimensions() {
        #expect(PlaybackLayout.bottomBar.size.width == 540)
        #expect(PlaybackLayout.bottomBar.size.height == 112)
    }

}
