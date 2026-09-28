import SwiftUI
import QuartzCore

class PopoverManager: NSObject, NSWindowDelegate {
    private let window: PopoverWindow
    private let presentation: PlayerPresentation
    private let defaults: UserDefaults
    var windowFrame: NSRect { window.frame }
    var isVisible: Bool { window.isVisible }
    private var layout: PlaybackLayout = .square
    private var focusEnabled = false
    private var focusAnchor: FocusAnchor = .automatic
    private var compactOrigin: NSPoint?
    private var expandedFrame = NSRect.zero
    private var hoverTask: Task<Void, Never>?
    private var dragging = false
    private var resizing = false
    private var resizeGeneration = 0
    private var frameName: String { layout == .square ? "PlaybackPanel" : "PlaybackPanel.bottomBar" }
    private var savedFrameKey: String { "playback.savedFrame.\(layout.rawValue)" }
    private let visibilityKey = "playbackPanelVisible"

    init<Content: View>(contentView: Content, presentation: PlayerPresentation, defaults: UserDefaults = .standard) {
        window = PopoverWindow(rootView: contentView)
        self.presentation = presentation
        self.defaults = defaults
        super.init()
        window.delegate = self
        presentation.hoverChanged = { [weak self] in self?.hoverChanged($0) }
        presentation.dragChanged = { [weak self] in self?.dragChanged($0) }
        presentation.expand = { [weak self] in self?.setExpanded(true) }
    }

    func configure(layout: PlaybackLayout, focus: Bool, anchor: FocusAnchor = .automatic) {
        hoverTask?.cancel()
        if focusAnchor != anchor && !presentation.compact { compactOrigin = nil }
        focusAnchor = anchor
        let changingLayout = self.layout != layout || expandedFrame == .zero
        if changingLayout {
            if expandedFrame != .zero { savePosition() }
            self.layout = layout
            resizing = true
            window.delegate = nil
            var restored = false
            if let saved = defaults.string(forKey: savedFrameKey) {
                let frame = NSRectFromString(saved)
                if frame.width > 0 && frame.height > 0 {
                    window.setFrame(frame, display: false); restored = true
                }
            }
            if !restored { restored = window.setFrameUsingName(frameName) }
            window.setContentSize(layout.size)
            if !restored, let screen = window.screen ?? NSScreen.main {
                let bounds = screen.visibleFrame
                window.setFrameOrigin(NSPoint(x: bounds.midX - layout.size.width / 2,
                    y: layout == .bottomBar ? bounds.minY + 20 : bounds.maxY - layout.size.height - 20))
            }
            window.delegate = self
            expandedFrame = window.frame
            compactOrigin = nil
            resizing = false
        }
        focusEnabled = focus && layout == .bottomBar
        if focusEnabled && changingLayout,
           defaults.integer(forKey: "playback.focusAnchorVersion") >= 1,
           let saved = defaults.string(forKey: "playback.focusOrigin") {
            compactOrigin = NSPointFromString(saved)
        }
        if !focusEnabled {
            presentation.anchor = .bottomLeft
            presentation.compact = false
            resize(to: clamped(expandedFrame), animated: false)
            compactOrigin = nil
        } else {
            let reference = compactOrigin.map { NSRect(origin: $0, size: FocusGeometry.compactSize) } ?? expandedFrame
            presentation.anchor = focusAnchor.resolved(for: reference, in: visibleBounds)
            if compactOrigin == nil {
                compactOrigin = FocusGeometry.collapsed(from: expandedFrame, in: visibleBounds, anchor: presentation.anchor).origin
            }
            // Preserve a compact token's location when the user changes direction.
            let compact = NSRect(origin: compactOrigin!, size: FocusGeometry.compactSize)
            expandedFrame = FocusGeometry.expanded(from: compact, in: visibleBounds, anchor: presentation.anchor)
            setExpanded(false, animated: false)
            savePosition()
        }
    }

    private var visibleBounds: NSRect {
        let frame = window.frame
        return NSScreen.screens.max { first, second in
            area(first.visibleFrame.intersection(frame)) < area(second.visibleFrame.intersection(frame))
        }?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
    private func area(_ rect: NSRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    private func clamped(_ frame: NSRect) -> NSRect { FocusGeometry.clamped(frame, to: visibleBounds) }

    func restoreVisibility(relativeTo button: NSStatusBarButton?) {
        if defaults.object(forKey: visibilityKey) as? Bool ?? true { show() }
    }

    func toggle(relativeTo button: NSStatusBarButton?) {
        if window.isVisible { dismiss() } else { show() }
    }

    private func show() {
        resize(to: clamped(window.frame), animated: false)
        if presentation.compact { compactOrigin = window.frame.origin }
        presentation.visible = true
        window.orderFrontRegardless()
        defaults.set(true, forKey: visibilityKey)
        if focusEnabled && window.frame.contains(NSEvent.mouseLocation) { hoverChanged(true) }
    }

    private func hoverChanged(_ inside: Bool) {
        guard focusEnabled, !resizing else { return }
        hoverTask?.cancel()
        guard !dragging else { return }
        hoverTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: inside ? 180_000_000 : 900_000_000)
                guard let self, self.window.isVisible, self.focusEnabled, !self.dragging else { return }
                let stillInside = self.window.frame.insetBy(dx: -3, dy: -3).contains(NSEvent.mouseLocation)
                guard inside == stillInside else { return }
                if !inside && NSEvent.pressedMouseButtons != 0 {
                    self.hoverChanged(false) // never fold under an active seek or mouse drag
                    return
                }
                self.setExpanded(inside)
            } catch { }
        }
    }

    private func dragChanged(_ active: Bool) {
        dragging = active
        hoverTask?.cancel()
        if !active {
            savePosition()
            hoverChanged(window.frame.contains(NSEvent.mouseLocation))
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard focusEnabled, !animated || presentation.compact == expanded else { return }
        hoverTask?.cancel()
        if expanded {
            let compact = NSRect(origin: compactOrigin ?? window.frame.origin, size: FocusGeometry.compactSize)
            presentation.anchor = focusAnchor.resolved(for: compact, in: visibleBounds)
            expandedFrame = FocusGeometry.expanded(from: compact, in: visibleBounds, anchor: presentation.anchor)
            presentation.compact = false
            resize(to: expandedFrame, animated: animated)
        } else {
            if compactOrigin == nil { compactOrigin = FocusGeometry.collapsed(from: expandedFrame, in: visibleBounds, anchor: presentation.anchor).origin }
            let compact = clamped(NSRect(origin: compactOrigin!, size: FocusGeometry.compactSize))
            compactOrigin = compact.origin
            presentation.compact = true
            resize(to: compact, animated: animated)
        }
    }

    private func resize(to frame: NSRect, animated: Bool) {
        resizeGeneration += 1
        let generation = resizeGeneration
        resizing = true
        if animated && window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                guard let self, generation == self.resizeGeneration else { return }
                self.resizing = false
                self.hoverChanged(self.window.frame.insetBy(dx: -3, dy: -3).contains(NSEvent.mouseLocation))
            }
        } else {
            window.setFrame(frame, display: true)
            resizing = false
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard !resizing else { return }
        if presentation.compact {
            compactOrigin = window.frame.origin
            presentation.anchor = focusAnchor.resolved(for: window.frame, in: visibleBounds)
            expandedFrame = FocusGeometry.expanded(from: window.frame, in: visibleBounds, anchor: presentation.anchor)
        } else {
            expandedFrame = window.frame
            if focusEnabled {
                presentation.anchor = focusAnchor.resolved(for: expandedFrame, in: visibleBounds)
                compactOrigin = FocusGeometry.collapsed(from: expandedFrame, in: visibleBounds, anchor: presentation.anchor).origin
            }
        }
        savePosition()
    }

    private func savePosition() {
        guard expandedFrame != .zero else { return }
        defaults.set(NSStringFromRect(expandedFrame), forKey: savedFrameKey)
        if focusEnabled, let compactOrigin {
            defaults.set(NSStringFromPoint(compactOrigin), forKey: "playback.focusOrigin")
            defaults.set(1, forKey: "playback.focusAnchorVersion")
        }
    }

    func dismiss() {
        hoverTask?.cancel()
        savePosition()
        window.orderOut(nil)
        presentation.visible = false // stop all decorative timelines while hidden
        if focusEnabled { setExpanded(false, animated: false) }
        defaults.set(false, forKey: visibilityKey)
    }
}
