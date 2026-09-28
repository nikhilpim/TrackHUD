import Foundation

/// Native track IDs prevent metadata/artwork refreshes from being mistaken for a new song.
struct PlaybackTrackIdentity: Hashable {
    let player: String
    let track: String

    init(player: String, trackID: String?, artist: String, title: String) {
        self.player = player
        if let trackID, !trackID.isEmpty {
            track = trackID
        } else {
            // Some streams have no persistent ID. Use raw metadata, not formatted labels.
            track = "metadata:\(artist.utf8.count):\(artist)\(title)"
        }
    }
}

/// One shared state machine feeds both the player and Appearance preview.
/// Each cycle visits every concrete theme once, with no immediate repeats.
struct ThemeRotation {
    private(set) var current: BarStyle = .studio
    private var lastTrack: PlaybackTrackIdentity?

    mutating func start(from style: BarStyle) {
        if style != .rotation { current = style }
    }

    mutating func observe(_ track: PlaybackTrackIdentity?, enabled: Bool) {
        // Ignore temporary missing metadata (including stop/start and failed polling).
        guard let track else { return }
        defer { lastTrack = track }
        guard enabled, let previous = lastTrack, previous != track else { return }
        let themes = BarStyle.rotationThemes
        let index = themes.firstIndex(of: current) ?? 0
        current = themes[(index + 1) % themes.count]
    }
}
