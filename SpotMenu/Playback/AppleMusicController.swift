import AppKit
import Foundation
import SwiftUI

class AppleMusicController: MusicPlayerController {
    private var lastArtist: String?
    private var lastTitle: String?
    private var lastImage: NSImage?

    @MainActor func fetchNowPlayingInfo() async -> PlaybackInfo? {
        let script = """
                tell application \"Music\"
                    if it is running then
                        set trackName to name of current track
                        set trackIdentifier to ""
                        try
                            set trackIdentifier to persistent ID of current track
                        end try
                        set artistName to artist of current track
                        set durationSec to duration of current track
                        set currentSec to player position
                        set isPlayingState to (player state is playing)
                        return trackName & \"|||SEP|||\" & artistName & \"|||SEP|||\" & durationSec & \"|||SEP|||\" & currentSec & \"|||SEP|||\" & isPlayingState & "|||SEP|||" & trackIdentifier
                    else
                        return \"NOT_RUNNING\"
                    end if
                end tell
            """

        guard let output = await runAppleScriptAsync(script), output != "NOT_RUNNING"
        else {
            return nil
        }

        let parts = output.components(separatedBy: "|||SEP|||")
        if parts.count == 6 {
            let artist = parts[1]
            let title = parts[0]
            let totalTime =
                Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 1
            let currentTime =
                Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0
            let isPlaying =
                parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
                == "true"

            if artist != lastArtist || title != lastTitle {
                lastImage = await getCurrentTrackArtwork()
                lastArtist = artist
                lastTitle = title
            }

            return PlaybackInfo(
                artist: artist,
                title: title,
                isPlaying: isPlaying,
                imageURL: nil,
                totalTime: totalTime,
                currentTime: currentTime,
                image: lastImage != nil ? Image(nsImage: lastImage!) : nil,
                isLiked: nil,
                longFormInfo: nil,
                trackID: parts[5].trimmingCharacters(in: .whitespacesAndNewlines),
                artworkImage: lastImage
            )
        }

        return nil
    }

    @MainActor func getCurrentTrackArtwork() async -> NSImage? {
        let script = """
            tell application \"Music\"
                    if it is running then
                        get data of artwork 1 of current track
                    end if
            end tell
            """

        guard let data = await runAppleScriptDataAsync(script) else { return nil }
        return NSImage(data: data)
    }

    func togglePlayPause() {
        _ = runAppleScript("tell application \"Music\" to playpause")
    }

    func skipForward() {
        _ = runAppleScript("tell application \"Music\" to next track")
    }

    func skipBack() {
        _ = runAppleScript("tell application \"Music\" to previous track")
    }

    func updatePlaybackPosition(to seconds: Double) async {
        _ = await runAppleScriptAsync(
            "tell application \"Music\" to set player position to \(Int(seconds))"
        )
    }

    func openApp() {
        SpotMenu.openApp(bundleIdentifier: "com.apple.Music")
    }

    func toggleLiked() {
        print("Apple Music does not support liking tracks (yet).")
    }

    func likeTrack() {
        print("Apple Music does not support liking tracks (yet).")
    }

    func unlikeTrack() {
        print("Apple Music does not support unliking tracks (yet).")
    }
}
