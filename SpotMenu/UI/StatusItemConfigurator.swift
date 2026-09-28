import AppKit

final class StatusItemConfigurator {
    static func configure(
        statusItem: NSStatusItem,
        toggleAction: Selector,
        target: AnyObject
    ) {
        statusItem.length = NSStatusItem.squareLength
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = SpotMenuLogo.image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "SpotMenu — click to show or hide player; right-click for options"
        button.setAccessibilityLabel("SpotMenu")
        button.setAccessibilityHelp("Show or hide the music player. Right-click for options.")
        button.action = toggleAction
        button.target = target
    }
}

/// A vector template image stays sharp on Retina displays and lets macOS handle
/// light/dark menu bars, accessibility contrast, and the pressed highlight.
enum SpotMenuLogo {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let frame = NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 16, height: 14),
                                     xRadius: 4.5, yRadius: 4.5)
            frame.lineWidth = 1.5
            frame.stroke()

            let waveform = NSBezierPath()
            waveform.lineWidth = 1.8
            waveform.lineCapStyle = .round
            for (x, height): (CGFloat, CGFloat) in [(5.5, 3), (9, 7), (12.5, 4.5)] {
                waveform.move(to: NSPoint(x: x, y: 9 - height / 2))
                waveform.line(to: NSPoint(x: x, y: 9 + height / 2))
            }
            waveform.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SpotMenu"
        return image
    }()
}
