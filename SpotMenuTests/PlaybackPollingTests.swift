import Combine
import Foundation
import SwiftUI
import Testing
@testable import SpotMenu

@Suite(.serialized)
struct PlaybackPollingTests {
    @Test @MainActor func slowScriptDoesNotBlockUIUpdates() async throws {
        var finished = false
        let poll = Task { @MainActor in
            let result = await runAppleScriptAsync("delay 0.5\nreturn \"ready\"")
            finished = true
            return result
        }

        // A main-actor UI update must run while AppleScript is still waiting.
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(!finished)
        let result = await poll.value
        #expect(result == "ready")
    }

    @Test @MainActor func pollingProgressDoesNotInvalidateDecorativeObservers() {
        let model = PlaybackModel(preferences: MusicPlayerPreferencesModel(), startsPolling: false)
        func snapshot(at time: Double, playing: Bool = true) -> PlaybackInfo {
            PlaybackInfo(artist: "Artist", title: "Track", isPlaying: playing,
                         imageURL: nil, totalTime: 180, currentTime: time,
                         image: Image(systemName: "music.note"), isLiked: nil,
                         longFormInfo: LongFormInfo(kind: .podcastEpisode, title: "Show",
                                                    authors: ["Host"], segmentTitle: "Episode"),
                         trackID: "test-track")
        }
        model.apply(snapshot(at: 0))
        var playerUpdates = 0
        var progressUpdates = 0
        let playerSubscription = model.objectWillChange.sink { playerUpdates += 1 }
        let progressSubscription = model.progress.objectWillChange.sink { progressUpdates += 1 }
        defer { playerSubscription.cancel(); progressSubscription.cancel() }

        for tick in 1...10 { model.apply(snapshot(at: Double(tick * 2))) }
        #expect(progressUpdates == 10)
        #expect(playerUpdates == 0)
        #expect(model.progress.currentTime == 20)

        // Real playback-state changes must still reach the animated views.
        model.apply(snapshot(at: 20, playing: false))
        #expect(playerUpdates == 1)
        #expect(progressUpdates == 10)
    }

    @Test @MainActor func progressAndDurationWritesStayInProgressSubtree() {
        let model = PlaybackModel(preferences: MusicPlayerPreferencesModel(), startsPolling: false)
        var playerUpdates = 0
        var progressUpdates = 0
        let playerSubscription = model.objectWillChange.sink { playerUpdates += 1 }
        let progressSubscription = model.progress.objectWillChange.sink { progressUpdates += 1 }
        defer { playerSubscription.cancel(); progressSubscription.cancel() }
        model.currentTime = 30
        model.totalTime = 200
        model.currentTime = 30
        model.totalTime = 200
        #expect(playerUpdates == 0)
        #expect(progressUpdates == 2)
    }

    @Test func decorativeViewInputsExcludeProgress() {
        let material = TransformingMaterial(style: .solar, isPlaying: true, motion: .lively)
        #expect(material == TransformingMaterial(style: .solar, isPlaying: true, motion: .lively))
        #expect(material != TransformingMaterial(style: .solar, isPlaying: false, motion: .lively))
        #expect(material != TransformingMaterial(style: .mercury, isPlaying: true, motion: .lively))
        let bars = PlaybackVisualizer(isPlaying: true, motion: .lively, style: .solar)
        #expect(bars == PlaybackVisualizer(isPlaying: true, motion: .lively, style: .solar))
        #expect(bars != PlaybackVisualizer(isPlaying: true, motion: .off, style: .solar))
    }

    @Test func failedScriptReturnsNoPlaybackData() async {
        let result = await runAppleScriptAsync("error \"unavailable\"")
        #expect(result == nil)
        let data = await runAppleScriptDataAsync("error \"unavailable\"")
        #expect(data == nil)
    }
}
