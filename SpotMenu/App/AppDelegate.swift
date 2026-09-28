import Combine
import KeyboardShortcuts
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var playbackAppearancePreferencesModel =
        PlaybackAppearancePreferencesModel()
    var musicPlayerPreferencesModel = MusicPlayerPreferencesModel()
    var playbackModel: PlaybackModel!
    var menuBarPreferencesModel = MenuBarPreferencesModel()
    var popoverManager: PopoverManager!
    let playerPresentation = PlayerPresentation()
    var preferencesWindow: NSWindow?
    private var layoutCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        playbackModel = PlaybackModel(preferences: musicPlayerPreferencesModel)

        // Configure status item and button
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        // Handle right-click menu
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) {
            [weak self] event in
            if self?.handleRightClick(event: event) == true { return nil }
            return event
        }

        // Observe playback updates
        NotificationCenter.default.addObserver(
            forName: .contentModelDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusItem()
        }

        // Set up popover manager
        let playbackView = FloatingPlayerRoot(
            model: playbackModel,
            preferences: playbackAppearancePreferencesModel,
            musicPreferences: musicPlayerPreferencesModel,
            presentation: playerPresentation
        )
        popoverManager = PopoverManager(contentView: playbackView, presentation: playerPresentation)
        popoverManager.configure(layout: playbackAppearancePreferencesModel.layout, focus: playbackAppearancePreferencesModel.focusMode,
                                 anchor: playbackAppearancePreferencesModel.focusAnchor)
        layoutCancellable = Publishers.CombineLatest3(
            playbackAppearancePreferencesModel.$layout.removeDuplicates(),
            playbackAppearancePreferencesModel.$focusMode.removeDuplicates(),
            playbackAppearancePreferencesModel.$focusAnchor.removeDuplicates()
        )
        .dropFirst()
        .receive(on: RunLoop.main)
        .sink { [weak self] layout, focus, anchor in
            self?.popoverManager.configure(layout: layout, focus: focus, anchor: anchor)
        }

        // Update UI periodically
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            self?.updateStatusItem()
        }

        StatusItemConfigurator.configure(
            statusItem: statusItem,
            toggleAction: #selector(togglePopover),
            target: self
        )

        setupKeyboardShortcuts()
        updateStatusItem()
        popoverManager.restoreVisibility(relativeTo: statusItem.button)

    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        SpotifyAuthManager.shared.handleRedirect(url: url)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .playPause) { [weak self] in
            self?.playbackModel.togglePlayPause()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .nextTrack) { [weak self] in
            self?.playbackModel.skipForward()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .previousTrack) { [weak self] in
            self?.playbackModel.skipBack()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleLike) { [weak self] in
            self?.playbackModel.toggleLiked()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .likeTrack) { [weak self] in
            self?.playbackModel.likeTrack()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .unlikeTrack) { [weak self] in
            self?.playbackModel.unlikeTrack()
            // Immediately update status item for keyboard shortcut feedback
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
    }

    func updateStatusItem() {
        playbackAppearancePreferencesModel.observeTrack(playbackModel.trackIdentity)
        // The menu-bar logo is deliberately static; metadata stays in the player.
    }

    @objc func togglePopover() {
        popoverManager.toggle(relativeTo: statusItem.button)
    }

    private func handleRightClick(event: NSEvent) -> Bool {
        guard let button = statusItem.button,
            event.window === button.window,
            button.bounds.contains(
                button.convert(event.locationInWindow, from: nil)
            )
        else { return false }

        statusItem.menu = MenuBuilder.build(delegate: self)
        button.performClick(nil)
        statusItem.menu = nil
        return true
    }

    @objc func refreshAction() {
        playbackModel.fetchInfo()
    }

    @objc func preferencesAction() {
        if preferencesWindow == nil {
            let hostingController = NSHostingController(
                rootView: PreferencesView(
                    menuBarPreferencesModel: menuBarPreferencesModel,
                    playbackModel: playbackModel,
                    musicPlayerPreferencesModel: musicPlayerPreferencesModel,
                    playbackAppearancePreferencesModel:
                        playbackAppearancePreferencesModel
                )
            )

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [
                .titled, .closable, .miniaturizable, .resizable,
                .fullSizeContentView,
            ]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden

            // Configure toolbar for modern macOS look
            let toolbar = NSToolbar(identifier: "PreferencesToolbar")
            toolbar.displayMode = .iconOnly
            window.toolbar = toolbar
            window.toolbarStyle = .unified

            // Set window size
            window.setContentSize(NSSize(width: 700, height: 500))
            window.minSize = NSSize(width: 600, height: 400)
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .normal

            // Modern rounded corners
            window.backgroundColor = .clear
            window.isOpaque = false

            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.makeMain()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

}

func nsImage<Content: View>(
    from view: Content,
    size: CGSize,
    scale: CGFloat = 1.0
) -> NSImage? {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = CGRect(origin: .zero, size: size)

    let rep = hostingView.bitmapImageRepForCachingDisplay(
        in: hostingView.bounds
    )
    guard let imageRep = rep else { return nil }

    hostingView.cacheDisplay(in: hostingView.bounds, to: imageRep)

    let nsImage = NSImage(size: size)
    nsImage.addRepresentation(imageRep)

    return nsImage
}
