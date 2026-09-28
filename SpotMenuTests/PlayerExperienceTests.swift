import AppKit
import SwiftUI
import Testing
@testable import SpotMenu

struct PlayerExperienceTests {
    private func solidImage(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
                                bytesPerRow: 128, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [red, green, blue, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return context.makeImage()!
    }

    @Test func animationClockKeepsPhaseThroughRefreshPauseAndResume() {
        var clock = AnimationPhaseClock()
        #expect(clock.elapsed(at: 1_000_000) == 0)
        clock.setRunning(true, at: 1_000_000)
        #expect(clock.elapsed(at: 1_000_002) == 2)
        clock.setRunning(true, at: 1_000_002) // unchanged playback metadata must not restart it
        #expect(clock.elapsed(at: 1_000_003) == 3)
        clock.setRunning(false, at: 1_000_003)
        #expect(clock.elapsed(at: 1_000_100) == 3)
        clock.setRunning(true, at: 1_000_100)
        #expect(clock.elapsed(at: 1_000_101) == 4)
    }

    @Test func playbackMotionSettlesToStaticAndResumesWithoutResetting() {
        var state = PlaybackMotionState()
        state.setPlaying(true, animated: true)
        for _ in 0..<60 { state.advance(by: 1.0 / 60) }
        #expect(state.energy == 1)
        let playingTime = state.time
        state.setPlaying(false, animated: true)
        state.advance(by: 0.3)
        #expect(state.energy > 0 && state.energy < 1)
        #expect(state.time > playingTime)
        for _ in 0..<60 { state.advance(by: 1.0 / 60) }
        #expect(state.energy == 0)
        #expect(!state.needsFrames)
        let restingTime = state.time
        state.advance(by: 100)
        #expect(state.time == restingTime)
        state.setPlaying(true, animated: true)
        #expect(state.time == restingTime)
        state.advance(by: 0.3)
        #expect(state.energy > 0 && state.energy < 1)
        #expect(state.time > restingTime)
    }

    @Test func playbackMotionReversesSmoothlyAndCanDisableImmediately() {
        var state = PlaybackMotionState()
        state.setPlaying(true, animated: true)
        state.advance(by: 0.3)
        let energy = state.energy
        let time = state.time
        state.setPlaying(false, animated: true)
        #expect(state.energy == energy && state.time == time)
        state.advance(by: 0.1)
        #expect(state.energy < energy)
        let fallingEnergy = state.energy
        state.setPlaying(true, animated: true)
        #expect(state.energy == fallingEnergy)
        state.advance(by: 0.1)
        #expect(state.energy > fallingEnergy)
        state.setPlaying(false, animated: false)
        #expect(state.energy == 0 && !state.needsFrames)
    }

    @Test @MainActor func playbackDriverStopsSchedulingAfterSettling() async throws {
        let driver = PlaybackMotionDriver()
        let playing = Task { await driver.run(playing: true, enabled: true) }
        defer { playing.cancel() }
        for _ in 0..<100 {
            if driver.state.energy > 0.05 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(driver.state.time > 0)
        playing.cancel()
        await playing.value
        await driver.run(playing: false, enabled: true)
        #expect(driver.state.energy == 0 && !driver.state.needsFrames)
        let restingTime = driver.state.time
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(driver.state.time == restingTime)
        await driver.run(playing: true, enabled: false)
        #expect(!driver.state.needsFrames)
    }

    @Test @MainActor func solarFramesActuallyChangeWithTimelineTime() throws {
        func pixels(at time: Double) throws -> Data {
            let renderer = ImageRenderer(content: SolarFrame(time: time, lively: true).frame(width: 540, height: 112))
            let image = try #require(renderer.cgImage)
            let data = try #require(image.dataProvider?.data)
            return data as Data
        }
        let first = try pixels(at: 0)
        #expect(first == (try pixels(at: 0)))
        #expect(first != (try pixels(at: 0.5)))
        #expect(try pixels(at: 0.5) != pixels(at: 1))
    }

    @Test func solarCrestsMoveContinuouslyAtDisplayCadence() {
        for strand in 0..<4 {
            for x in stride(from: 0.0, through: 540, by: 13) {
                for time in stride(from: 0.0, through: 20, by: 0.2) {
                    let first = SolarPlasma.offset(x: x, time: time, strand: strand, amplitude: 13)
                    let next = SolarPlasma.offset(x: x, time: time + 1.0 / 60, strand: strand, amplitude: 13)
                    #expect(first.isFinite && next.isFinite)
                    #expect(abs(next - first) < 0.31)
                }
            }
        }
    }

    @Test func artworkPaletteRecognizesColorAndHandlesBlack() {
        let red = ArtworkPalette.extract(from: solidImage(red: 1, green: 0, blue: 0))
        #expect(red.primary.red > 0.95)
        #expect(red.primary.green < 0.05)
        #expect(red.primary.blue < 0.05)
        #expect(ArtworkPalette.extract(from: solidImage(red: 0, green: 0, blue: 0)) == .neutral)
    }

    @Test @MainActor func artworkCacheIgnoresRepeatedPollingAndStaleLoads() async throws {
        let store = ArtworkStore()
        let red = NSImage(cgImage: solidImage(red: 1, green: 0, blue: 0), size: .zero)
        let blue = NSImage(cgImage: solidImage(red: 0, green: 0, blue: 1), size: .zero)
        let first = PlaybackTrackIdentity(player: "test", trackID: "red", artist: "", title: "")
        let second = PlaybackTrackIdentity(player: "test", trackID: "blue", artist: "", title: "")
        store.update(url: nil, fallback: red, identity: first)
        store.update(url: nil, fallback: blue, identity: second)
        for _ in 0..<100 {
            if store.palette.primary.blue > 0.95 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(store.palette.primary.blue > 0.95)
        #expect(store.palette.primary.red < 0.05)
        let cached = store.image
        store.update(url: nil, fallback: blue, identity: second)
        #expect(store.image === cached)
        store.update(url: nil, fallback: nil, identity: nil)
        #expect(store.image == nil)
        #expect(store.palette == .neutral)
    }

    @Test @MainActor func trackRevealKeepsOutgoingLayerAndQueuesOnlyLatestPair() async throws {
        let reveal = TrackReveal()
        defer { reveal.stop() }
        let first = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
        let second = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
        let skipped = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
        let latest = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
        reveal.request(style: .solar, artwork: first, animated: true)
        let originalID = reveal.layers[0].id
        reveal.request(style: .mercury, artwork: second, animated: true)
        #expect(reveal.layers.count == 2)
        #expect(reveal.layers[0].id == originalID)
        #expect(reveal.layers[0].artwork.id == first.id)
        #expect(reveal.layers[1].artwork.id == second.id)
        #expect(reveal.progress == 0)
        let incomingID = reveal.layers[1].id
        reveal.request(style: .ember, artwork: skipped, animated: true)
        reveal.request(style: .radar, artwork: latest, animated: true)
        #expect(reveal.layers.count == 2)
        for _ in 0..<150 {
            if reveal.layers.last?.artwork.id == latest.id { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(reveal.layers.count == 2)
        #expect(reveal.layers.first?.id == incomingID)
        #expect(reveal.layers.last?.style == .radar)
        #expect(reveal.layers.last?.artwork.id == latest.id)
        reveal.request(style: .radar, artwork: latest, animated: false)
        #expect(reveal.layers.count == 1 && reveal.progress == 1)
    }

    @Test @MainActor func manualThemeSelectionInterruptsAndDiscardsQueuedTracks() async throws {
        let reveal = TrackReveal()
        defer { reveal.stop() }
        let artwork = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
        reveal.request(style: .studio, artwork: artwork, animated: true)
        reveal.request(style: .solar, artwork: artwork, animated: true)
        reveal.request(style: .radar, artwork: artwork, animated: true)
        let outgoingID = reveal.layers.last?.id
        reveal.request(style: .neon, artwork: artwork, animated: true, interrupt: true)
        #expect(reveal.layers.count == 2)
        #expect(reveal.layers.first?.id == outgoingID)
        #expect(reveal.layers.last?.style == .neon)
        #expect(reveal.progress == 0)
        for _ in 0..<150 {
            if reveal.layers.count == 1 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(reveal.layers.count == 1)
        #expect(reveal.layers.last?.style == .neon)
        // Clicking the selected tile is an explicit replay, not a no-op.
        reveal.request(style: .neon, artwork: artwork, animated: true, interrupt: true)
        #expect(reveal.layers.count == 2 && reveal.progress == 0)
        reveal.request(style: .ember, artwork: artwork, animated: false, interrupt: true)
        #expect(reveal.layers.count == 1 && reveal.progress == 1)
        #expect(reveal.layers.last?.style == .ember)
    }

    @Test @MainActor func artworkReadinessRetainsPreviousSnapshotUntilNewCoverIsDecoded() async throws {
        let store = ArtworkStore()
        let first = PlaybackTrackIdentity(player: "test", trackID: "first", artist: "", title: "")
        let second = PlaybackTrackIdentity(player: "test", trackID: "second", artist: "", title: "")
        let image = NSImage(cgImage: solidImage(red: 1, green: 0, blue: 0), size: .zero)
        store.update(url: nil, fallback: image, identity: first)
        for _ in 0..<100 {
            if store.resolved.identity == first { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(store.resolved.identity == first)
        let previous = store.resolved.id
        store.update(url: nil, fallback: image, identity: second)
        #expect(store.resolved.id == previous)
        for _ in 0..<100 {
            if store.resolved.identity == second { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(store.resolved.identity == second)
        #expect(store.resolved.image != nil)
        store.update(url: nil, fallback: nil, identity: first)
        #expect(store.resolved.identity == first && store.resolved.image == nil)
    }

    @Test @MainActor func failedArtworkResolvesWithoutRepeatedPlaceholderReveals() async throws {
        let store = ArtworkStore()
        let identity = PlaybackTrackIdentity(player: "test", trackID: "missing", artist: "", title: "")
        let url = URL(string: "unsupported-artwork://missing")!
        store.update(url: url, fallback: nil, identity: identity)
        for _ in 0..<100 {
            if store.resolved.identity == identity { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(store.resolved.identity == identity && store.resolved.image == nil)
        let snapshotID = store.resolved.id
        store.update(url: url, fallback: nil, identity: identity)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(store.resolved.id == snapshotID)
    }

    @Test func materialRevealCoversNeitherThenAllOfTheSurface() {
        let size = CGSize(width: 540, height: 112)
        for y in stride(from: CGFloat(0), through: size.height, by: 7) {
            #expect(MaterialReveal.boundary(progress: 0, y: y, size: size) < 0)
            #expect(MaterialReveal.boundary(progress: 1, y: y, size: size) > size.width)
            #expect(MaterialReveal.boundary(progress: 0.5, y: y, size: size).isFinite)
        }
    }

    @Test func focusExpansionPreservesCornerAndStaysOnScreen() {
        let bounds = NSRect(x: -1440, y: 40, width: 1440, height: 860)
        let compact = NSRect(x: -900, y: 100, width: 84, height: 84)
        let expanded = FocusGeometry.expanded(from: compact, in: bounds, anchor: .bottomLeft)
        #expect(expanded.size == NSSize(width: 540, height: 112))
        #expect(expanded.minX == compact.minX)
        #expect(expanded.minY == compact.minY)
        #expect(FocusGeometry.collapsed(from: expanded, in: bounds, anchor: .bottomLeft) == compact)
        for origin in [NSPoint(x: -1440, y: 40), NSPoint(x: -84, y: 816)] {
            let edge = FocusGeometry.expanded(from: NSRect(origin: origin, size: FocusGeometry.compactSize), in: bounds)
            #expect(bounds.contains(edge))
        }
    }

    @Test func allFocusCornersRoundTripOnOffsetDisplays() {
        for bounds in [NSRect(x: 0, y: 40, width: 1440, height: 860), NSRect(x: -1920, y: -900, width: 1920, height: 1080)] {
            for anchor in FocusAnchor.allCases where anchor != .automatic {
                let compact = NSRect(x: anchor.isRight ? bounds.maxX - 84 : bounds.minX,
                                     y: anchor.isTop ? bounds.maxY - 84 : bounds.minY, width: 84, height: 84)
                #expect(FocusAnchor.automatic.resolved(for: compact, in: bounds) == anchor)
                let expanded = FocusGeometry.expanded(from: compact, in: bounds, anchor: anchor)
                #expect(bounds.contains(expanded))
                #expect(FocusGeometry.collapsed(from: expanded, in: bounds, anchor: anchor) == compact)
                if anchor.isRight { #expect(expanded.maxX == compact.maxX) }
                else { #expect(expanded.minX == compact.minX) }
                if anchor.isTop { #expect(expanded.maxY == compact.maxY) }
                else { #expect(expanded.minY == compact.minY) }
            }
        }
    }

    @Test @MainActor func bottomRightFocusKeepsCornerAcrossCyclesAndDirectionChanges() {
        let name = "SpotMenuTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let bounds = NSScreen.main!.visibleFrame
        let original = NSRect(x: bounds.maxX - 550, y: bounds.minY + 10, width: 540, height: 112)
        defaults.set(NSStringFromRect(original), forKey: "playback.savedFrame.bottomBar")
        // An old artwork-anchored token should migrate to the saved bar's corner.
        defaults.set(NSStringFromPoint(NSPoint(x: original.minX + 12, y: original.minY + 8)), forKey: "playback.focusOrigin")
        let state = PlayerPresentation()
        let manager = PopoverManager(contentView: Color.clear, presentation: state, defaults: defaults)
        manager.configure(layout: .bottomBar, focus: true, anchor: .bottomRight)
        let compact = manager.windowFrame
        #expect(compact.maxX == original.maxX)
        #expect(compact.minY == original.minY)
        for _ in 0..<3 {
            state.expand()
            #expect(manager.windowFrame == original)
            manager.dismiss()
            #expect(manager.windowFrame == compact)
        }
        manager.configure(layout: .bottomBar, focus: true, anchor: .topRight)
        #expect(manager.windowFrame == compact) // changing direction never relocates a compact token
        state.expand()
        #expect(manager.windowFrame.maxX == compact.maxX)
        manager.dismiss()
        #expect(manager.windowFrame == compact)
        // Persisted focus position, not an artwork offset, is restored after relaunch.
        let restoredState = PlayerPresentation()
        let restored = PopoverManager(contentView: Color.clear, presentation: restoredState, defaults: defaults)
        restored.configure(layout: .bottomBar, focus: true, anchor: .bottomRight)
        #expect(restored.windowFrame == compact)
    }

    @Test @MainActor func focusModeChangesActualPanelDimensionsAndCanBeDisabled() {
        let name = "SpotMenuTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(NSStringFromRect(NSRect(x: 100, y: 100, width: 540, height: 112)), forKey: "playback.savedFrame.bottomBar")
        let state = PlayerPresentation()
        let manager = PopoverManager(contentView: Color.clear, presentation: state, defaults: defaults)
        manager.configure(layout: .bottomBar, focus: true)
        #expect(state.compact)
        #expect(manager.windowFrame.size == FocusGeometry.compactSize)
        state.expand()
        #expect(!state.compact)
        #expect(manager.windowFrame.size == PlaybackLayout.bottomBar.size)
        manager.configure(layout: .bottomBar, focus: true)
        #expect(state.compact)
        manager.configure(layout: .bottomBar, focus: false)
        #expect(!state.compact)
        #expect(manager.windowFrame.size == PlaybackLayout.bottomBar.size)
        manager.dismiss()
        #expect(!state.visible)
    }

    @Test @MainActor func newThemeSurfacesRenderInEveryMotionMode() {
        for style in BarStyle.rotationThemes {
            for motion in VisualizerMotion.allCases {
                let renderer = ImageRenderer(content: BarThemeBackground(style: style, isPlaying: false, motion: motion).frame(width: 540, height: 112))
                #expect(renderer.nsImage != nil)
            }
        }
    }
}
