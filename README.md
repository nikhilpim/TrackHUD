# SpotMenu

**Spotify & Apple Music in your macOS menu bar**

A minimalist music utility with a custom menu-bar logo and a movable, persistent player with playback controls and keyboard shortcuts. Built with Swift and SwiftUI.

![Demo](https://github.com/user-attachments/assets/4b6b8e15-7180-44f1-abf7-796566a02fbb)

---

## Features

- **Menu Bar Integration** — A compact custom logo toggles the player without track-title clutter
- **Playback Controls** — Hover overlay with play/pause, skip, and album art
- **Keyboard Shortcuts** — Global hotkeys for playback control
- **Track Liking** — Like/unlike tracks via Spotify Web API (Spotify only)
- **Player Designs** — Choose a square player or a themed bottom bar
- **Live Updates** — Automatically syncs with playback changes
- **Multi-Player Support** — Auto-detect or manually select Spotify / Apple Music
- **Fully Customizable** — Configure visuals, shortcuts, and behavior

---

## Installation

### Download

Get the latest release from [GitHub Releases](https://github.com/kmikiy/SpotMenu/releases/latest) and open `SpotMenu.app.zip`.

The app is signed and notarized, and includes automatic updates via Sparkle.

### Homebrew

```sh
brew install --cask spotmenu
```

### Build from Source

**Requirements:** macOS 13+ (Ventura), Xcode 15+

```bash
git clone https://github.com/kmikiy/SpotMenu.git
cd SpotMenu
open SpotMenu.xcodeproj
```

---

## Spotify Setup

To enable track liking/unliking, you need to set up a Spotify Developer App.

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Log in and click **Create an App**
3. Enter any name and description
4. In app settings, click **Edit Settings**
5. Under **Redirect URIs**, add:
   ```
   com.github.kmikiy.spotmenu://callback
   ```
6. Save and copy your **Client ID**
7. In SpotMenu, go to **Preferences → Music Player** and enable Track Liking
8. Paste your Client ID and complete the login flow

---

## Preferences

Access via right-click on the menu bar icon → **Preferences...**

### Music Player

Choose your music player:

- **Automatic** — Uses whichever player is active
- **Spotify**
- **Apple Music**

### Playback Appearance

Choose Square or Bottom Bar with **20 checkmarked style choices**, including
**Rotation**. The expanded bar stays 540 × 112, with full-color album art and fixed
playback controls. The refreshed collection favors luminous edges, clean geometry,
rich color, and dark readable surfaces over literal scenes or dense textures.

The five favorites remain: **Studio** (mint spectrum), **Neon** (perimeter trails),
**Blueprint** (technical traces), **Ember** (copper sparks), and **Prism** (iridescent ribbons).

Eleven new designs:
- **Aurora:** broad mint-and-violet light curtains.
- **Laser:** continuous overlapping coral and cyan laser trails.
- **Velvet:** traveling rose silk folds on black cherry.
- **Halogen:** coiled tungsten filaments with scanning incandescent hotspots.
- **Circuit:** connected cyan traces with smoothly flowing, overlapping signal trains.
- **Cascade:** staggered ice-blue light bars.
- **Eclipse:** dark eclipses and counter-rotating violet coronas across both rims.
- **Opal:** drifting, deforming pastel lenses with moving pearl caustics.
- **Ribbon:** interlaced fuchsia and tangerine curves.
- **Afterglow:** faster flowing sunset strata along both edges.
- **Mosaic:** smoothly folding jewel facets with traveling creases.

**Solar**, **Mercury**, and **Radar** remain available. Radar includes an upper
acquisition trace and scanning scale to balance its lower instruments. Retired Terminal, Deep Sea,
and Magnetic selections migrate to Circuit, Aurora, and Mosaic respectively.

Motion options: Off, Gentle, and Lively. All animation is decorative.
Pausing eases motion and glow into a static resting state over 0.9 seconds;
playing eases back in over 0.65 seconds without resetting the animation phase.
Off and Reduce Motion skip these transitions and keep decorative motion still.
Reactive mode and its audio capture code/permissions have been removed; saved
Reactive selections migrate to Lively. No audio, microphone, or screen capture is used.
Retired Focus selections migrate to Studio; Paper, Cassette, and Botanical migrate to Mercury.

**Rotation** cycles through all nineteen concrete themes once per cycle, changing on
new track IDs (with raw artist/title fallback for streams without IDs). A curved,
liquid front reveals the incoming material and album cover together over 1.8 seconds,
with a luminous seam and easing control colors. The old pair stays visible until the
new cover finishes loading (a failed download falls back to a placeholder); the
outgoing material keeps animating without restarting. Controls remain in place.
Manual theme clicks interrupt the current reveal and start a fresh wipe immediately,
without waiting for artwork; clicking the selected theme replays its reveal. Rapid track changes queue
only the latest theme, with at most two materials rendering during a transition. Pause/resume, seeking, and metadata refreshes do not
advance Rotation. The first observed track establishes the starting point; repeat
playback of the same track ID retains its theme. Enabling Rotation keeps your
current theme until the next track. Reduce Motion switches themes instantly.
The Appearance preview and player share the same rotation state.

**Album-art Lighting** extracts two cover colors using a small local thumbnail and
caches the palette with the image. The colors illuminate the surface without tinting
the artwork itself. Shared image loading avoids repeated downloads or per-frame analysis.

**Song Entrance** gives new tracks a short artwork settle, text entrance, and one
surface wave. **Physical Interaction** adds pointer-following reflections, a light
artwork tilt, click ripples, and a spring-like settle after dragging. Both are optional
in Appearance; Off and Reduce Motion disable these animations.

**Focus Mode** shrinks the actual panel to an 84 × 84 album-art jewel. Hover for
180 ms to unfold; leaving for 900 ms folds it back. It stays open during a drag or
seek. **Focus Anchor** offers Automatic (nearest corner), Bottom Left, Bottom Right,
Top Left, and Top Right. The selected window corner remains fixed when folding and
unfolding; Bottom Right expands left/up and returns the token to the same corner.
Dragging the expanded player also updates the token's corner position. Direction
changes while compact preserve the token's position. Panels are clamped to the
visible display when the requested direction has insufficient room.
Click the jewel to expand with the keyboard or
VoiceOver; drag its top edge to reposition. Disable Focus Mode to keep the full bar.
The Settings preview stays expanded. Hiding the player stops its decorative timelines.

Previously granted audio/screen permissions can be revoked in System Settings;
the current build neither requests nor uses them.

Customize the player overlay:

- Hover Tint Color
- Foreground Color
- Blur Intensity
- Hover Tint Opacity

### Menu Bar

A static, monochrome SpotMenu logo adapts to the menu bar’s appearance.
Click to show/hide the player; right-click for preferences and other options.
Track details and playback controls stay in the player.

### Shortcuts

Set global hotkeys for:

- Play / Pause
- Next / Previous Track
- Like / Unlike / Toggle Like (Spotify only)

---

## Usage

| Action         | Result                   |
| -------------- | ------------------------ |
| Left-click     | Show/hide playback panel |
| Right-click    | Open context menu        |
| Hover on panel | Reveal playback controls |

---

## Support

If you find SpotMenu useful, consider [supporting development](https://paypal.me/kmikiy).

---

## License

MIT License. See [LICENSE](LICENSE) for details.
