import Combine
import SwiftUI

extension Notification.Name {
    static let contentModelDidUpdate = Notification.Name(
        "PlaybackModelDidUpdate"
    )
}

enum PlayerType {
    case spotify
    case appleMusic
}

enum LongFormTitleStyle: String, CaseIterable, Identifiable {
    case titleOnly
    case segmentOnly
    case titleAndSegment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .titleOnly: return "Title Only"
        case .segmentOnly: return "Chapter/Episode Only"
        case .titleAndSegment: return "Title + Chapter/Episode"
        }
    }
}

enum PreferredPlayer: String, CaseIterable, Identifiable {
    case automatic
    case spotify
    case appleMusic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }
}

enum LongFormKind: Equatable {
    case audiobook
    case podcastEpisode
}

struct LongFormInfo: Equatable {
    let kind: LongFormKind
    let title: String      // book or show title
    let authors: [String]  // authors or publisher
    let segmentTitle: String? // chapter or episode title
}

struct PlaybackInfo {
    let artist: String
    let title: String
    let isPlaying: Bool
    let imageURL: URL?
    let totalTime: Double
    let currentTime: Double
    let image: Image?
    let isLiked: Bool?
    let longFormInfo: LongFormInfo?
    var trackID: String? = nil
    var artworkImage: NSImage? = nil
}

protocol MusicPlayerController {
    @MainActor func fetchNowPlayingInfo() async -> PlaybackInfo?
    func togglePlayPause()
    func skipForward()
    func skipBack()
    func updatePlaybackPosition(to seconds: Double) async
    func openApp()
    func toggleLiked()
    func likeTrack()
    func unlikeTrack()
}

/// Only the seek controls observe this object. Its ticks must not invalidate
/// the player root, material timelines, or decorative visualizer.
final class PlaybackProgress: ObservableObject {
    @Published var totalTime: Double = 1
    @Published var currentTime: Double = 0
}

class PlaybackModel: ObservableObject {
    let artwork = ArtworkStore()
    @Published private(set) var trackIdentity: PlaybackTrackIdentity?
    @Published var imageURL: URL?
    @Published var image: Image? = nil
    @Published var isPlaying: Bool = false
    @Published var title: String = ""
    @Published var artist: String = ""
    let progress = PlaybackProgress()
    var totalTime: Double {
        get { progress.totalTime }
        set { if progress.totalTime != newValue { progress.totalTime = newValue } }
    }
    var currentTime: Double {
        get { progress.currentTime }
        set { if progress.currentTime != newValue { progress.currentTime = newValue } }
    }
    @Published var playerType: PlayerType
    @Published var isLiked: Bool? = nil
    @Published var longFormInfo: LongFormInfo? = nil

    private let preferences: MusicPlayerPreferencesModel
    private var controller: MusicPlayerController
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var playerGeneration = 0

    private var cancellable: AnyCancellable?

    var playerIconName: String {
        return playerType == .appleMusic ? "AppleMusicIcon" : "SpotifyIcon"
    }

    var isLikingImplemented: Bool {
        return playerType == .spotify
    }

    init(preferences: MusicPlayerPreferencesModel, startsPolling: Bool = true) {
        self.preferences = preferences

        let (controller, type) = Self.selectController(
            for: preferences.preferredMusicApp,
            preferences: preferences
        )
        self.controller = controller
        self.playerType = type

        guard startsPolling else { return }
        fetchInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.fetchInfo()
        }

        cancellable = preferences.$preferredMusicApp
            .removeDuplicates()
            .sink { [weak self] newPreference in
                self?.switchPlayer(to: newPreference)
            }
    }

    deinit {
        timer?.invalidate()
        fetchTask?.cancel()
    }

    func switchPlayer(to newPreference: PreferredPlayer) {
        let (newController, newType) = Self.selectController(
            for: newPreference,
            preferences: preferences
        )
        playerGeneration += 1
        fetchTask?.cancel()
        fetchTask = nil
        controller = newController
        playerType = newType
        fetchInfo()
    }

    private static func selectController(
        for preference: PreferredPlayer,
        preferences: MusicPlayerPreferencesModel
    ) -> (
        MusicPlayerController, PlayerType
    ) {
        let spotifyInstalled = isAppInstalled("com.spotify.client")
        let appleMusicInstalled = isAppInstalled("com.apple.Music")
        let spotifyRunning = isAppRunning("com.spotify.client")
        let appleMusicRunning = isAppRunning("com.apple.Music")

        switch preference {
        case .appleMusic:
            return (AppleMusicController(), .appleMusic)
        case .spotify:
            return (SpotifyController(preferences: preferences), .spotify)
        case .automatic:
            if spotifyRunning {
                return (SpotifyController(preferences: preferences), .spotify)
            } else if appleMusicRunning {
                return (AppleMusicController(), .appleMusic)
            } else if spotifyInstalled {
                return (SpotifyController(preferences: preferences), .spotify)
            } else if appleMusicInstalled {
                return (AppleMusicController(), .appleMusic)
            } else {
                return (SpotifyController(preferences: preferences), .spotify)
            }
        }
    }

    private static func isAppInstalled(_ bundleIdentifier: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) != nil
    }

    private static func isAppRunning(_ bundleIdentifier: String) -> Bool {
        return NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).count > 0
    }

    func fetchInfo() {
        // Coalesce timer ticks while the player is slow or awaiting permission.
        guard fetchTask == nil else { return }
        let controller = controller
        let generation = playerGeneration
        fetchTask = Task { @MainActor [weak self] in
            let info = await controller.fetchNowPlayingInfo()
            guard let self, !Task.isCancelled,
                  generation == self.playerGeneration else { return }
            defer { self.fetchTask = nil }
            guard let info else {
                self.reset()
                return
            }
            self.apply(info)
        }
    }

    @MainActor func apply(_ info: PlaybackInfo) {
        let displayText = computeDisplayText(from: info)
        // Reassigning even identical @Published values invalidates subscribers.
        // A normal polling tick should publish only to the progress controls.
        if title != displayText.title { title = displayText.title }
        if artist != displayText.artist { artist = displayText.artist }
        if isPlaying != info.isPlaying { isPlaying = info.isPlaying }
        if imageURL != info.imageURL { imageURL = info.imageURL }
        totalTime = info.totalTime
        currentTime = info.currentTime
        if image != info.image { image = info.image }
        if isLiked != info.isLiked { isLiked = info.isLiked }
        if longFormInfo != info.longFormInfo { longFormInfo = info.longFormInfo }
        if !info.title.isEmpty {
            let identity = PlaybackTrackIdentity(
                player: playerType == .spotify ? "spotify" : "appleMusic",
                trackID: info.trackID, artist: info.artist, title: info.title
            )
            if trackIdentity != identity { trackIdentity = identity }
        }
        artwork.update(url: info.imageURL, fallback: info.artworkImage, identity: trackIdentity)

        NotificationCenter.default.post(name: .contentModelDidUpdate, object: nil)
    }

    func togglePlayPause() {
        // Execute the command first
        controller.togglePlayPause()
        
        // Small delay to allow the music player to process, then update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isPlaying.toggle()
            self.notifyModelUpdate()
        }
        
        delayedFetch()
    }

    func skipForward() {
        controller.skipForward()
        delayedFetch()
    }

    func skipBack() {
        controller.skipBack()
        delayedFetch()
    }

    func toggleLiked() {
        let previousLikeStatus = self.isLiked

        // Immediately update like status for UI responsiveness
        if let previous = previousLikeStatus {
            isLiked = !previous
        }
        
        // Send notification to update status bar immediately
        notifyModelUpdate()

        controller.toggleLiked()
        delayedFetch()
    }

    func likeTrack() {
        // Immediately update like status for UI responsiveness
        isLiked = true
        
        // Send notification to update status bar immediately
        notifyModelUpdate()
        
        controller.likeTrack()
    }

    func unlikeTrack() {
        // Immediately update like status for UI responsiveness
        isLiked = false
        
        // Send notification to update status bar immediately
        notifyModelUpdate()
        
        controller.unlikeTrack()
    }

    func updatePlaybackPosition(to seconds: Double) {
        self.currentTime = seconds
        let controller = controller
        Task { await controller.updatePlaybackPosition(to: seconds) }
    }

    func openMusicApp() {
        controller.openApp()
    }

    private func delayedFetch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.fetchInfo()
        }
    }
    
    private func notifyModelUpdate() {
        NotificationCenter.default.post(
            name: .contentModelDidUpdate,
            object: nil
        )
    }

    @MainActor private func reset() {
        trackIdentity = nil
        artwork.update(url: nil, fallback: nil, identity: nil)
        title = ""
        artist = ""
        isPlaying = false
        imageURL = nil
        currentTime = 0
        totalTime = 1
        image = nil
        isLiked = nil
        longFormInfo = nil
    }

    private func computeDisplayText(from info: PlaybackInfo)
        -> (artist: String, title: String)
    {
        guard let longFormInfo = info.longFormInfo else {
            return (info.artist, info.title)
        }

        let authorText = longFormInfo.authors.joined(separator: ", ")
        let baseTitle =
            longFormInfo.title.isEmpty ? info.title : longFormInfo.title
        let segmentTitle = longFormInfo.segmentTitle?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let titleText: String
        switch preferences.longFormTitleStyle {
        case .titleOnly:
            titleText = baseTitle
        case .segmentOnly:
            titleText = segmentTitle?.isEmpty == false ? segmentTitle!
                : baseTitle
        case .titleAndSegment:
            if let segment = segmentTitle,
                !segment.isEmpty,
                segment.caseInsensitiveCompare(baseTitle) != .orderedSame
            {
                titleText = "\(baseTitle) — \(segment)"
            } else {
                titleText = baseTitle
            }
        }

        let artistText = authorText.isEmpty ? info.artist : authorText

        return (artistText, titleText)
    }
}

// Keep script execution serialized, but never make periodic polling wait on
// the main thread. Only plain strings/data cross back to the UI.
private let appleScriptQueue = DispatchQueue(label: "SpotMenu.AppleScript", qos: .userInitiated)

func runAppleScript(_ script: String) -> String? {
    appleScriptQueue.sync {
        var error: NSDictionary?
        return NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
    }
}

func runAppleScriptAsync(_ script: String) async -> String? {
    await withCheckedContinuation { continuation in
        appleScriptQueue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            continuation.resume(returning: error == nil ? result?.stringValue : nil)
        }
    }
}

func runAppleScriptDataAsync(_ script: String) async -> Data? {
    await withCheckedContinuation { continuation in
        appleScriptQueue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            continuation.resume(returning: error == nil ? result?.data : nil)
        }
    }
}

func openApp(bundleIdentifier: String) {
    guard
        let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        )
    else {
        print("App with bundle ID \(bundleIdentifier) not found.")
        return
    }

    let config = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: url, configuration: config) {
        app,
        error in
        if let error = error {
            print("Failed to open app: \(error.localizedDescription)")
        }
    }
}
