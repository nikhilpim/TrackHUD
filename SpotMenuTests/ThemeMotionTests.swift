import AppKit
import SwiftUI
import Testing
@testable import SpotMenu

struct ThemeMotionTests {
    private let themes: [BarStyle] = [.laser, .velvet, .halogen, .circuit, .eclipse, .opal, .afterglow, .mosaic, .radar]

    @MainActor private func frame(_ style: BarStyle, time: Double, energy: Double = 1) throws -> CGImage {
        let renderer = ImageRenderer(content: Canvas { context, size in
            if style == .radar {
                WorldThemeEffects.draw(style, context: &context, size: size, time: 0, animated: false)
                context.opacity = 0.18 + 0.82 * energy
                WorldThemeEffects.draw(style, context: &context, size: size, time: time, animated: true)
            } else {
                RefreshedThemeEffects.draw(style, context: &context, size: size, time: time, energy: energy)
            }
        }.frame(width: 540, height: 112))
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                 bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count)
    }

    @Test @MainActor func improvedThemesMoveVisiblyWithoutFrameJumps() throws {
        for style in themes {
            let firstImage = try frame(style, time: 0.7)
            let first = try pixels(firstImage)
            let preview = ImageRenderer(content: Image(decorative: firstImage, scale: 1)
                .background(style.background))
            Attachment.record(try #require(preview.nsImage), named: "\(style.rawValue)-playing.png", as: .png)
            let adjacent = try pixels(frame(style, time: 0.7 + 1.0 / 60))
            let later = try pixels(frame(style, time: 1.2))
            let smallStep = difference(first, adjacent)
            let visibleStep = difference(first, later)
            #expect(visibleStep > 0.05, "\(style): should visibly change in half a second")
            #expect(smallStep < visibleStep, "\(style): adjacent frames should change less than a half-second interval")
            let resting = try pixels(frame(style, time: 1.2, energy: 0))
            #expect(resting == (try pixels(frame(style, time: 1.2, energy: 0))))
            #expect(resting != later)
        }
    }

    @Test @MainActor func laserWrapsWithoutPoppingAndSignalEdgesHaveNoEmptyColumns() throws {
        for speed in [62.0, 46] {
            for cycle in 1...3 {
                let wrap = Double(cycle) * 180 / speed
                let before = try pixels(frame(.laser, time: wrap - 0.0001))
                let after = try pixels(frame(.laser, time: wrap + 0.0001))
                #expect(difference(before, after) < 0.1)
            }
        }
        for style in [BarStyle.laser, .circuit] {
            for time in [0.0, 0.5, 2.9, 7.8] {
                let image = try pixels(frame(style, time: time))
                for x in stride(from: 24, through: 516, by: 4) {
                    for startY in [0, 88] {
                        var alpha: UInt8 = 0
                        for y in startY..<(startY + 24) {
                            alpha = max(alpha, image[(y * 540 + x) * 4 + 3])
                        }
                        #expect(alpha > 20, "\(style): empty edge at x=\(x), t=\(time)")
                    }
                }
            }
        }
    }

    @Test @MainActor func eclipseAndRadarHaveVisibleUpperAndLowerCompositions() throws {
        for style in [BarStyle.eclipse, .radar] {
            let image = try pixels(frame(style, time: 1))
            for startY in [0, 88] {
                var litColumns = 0
                for x in 24..<516 {
                    for y in startY..<(startY + 24) {
                        if image[(y * 540 + x) * 4 + 3] > 20 {
                            litColumns += 1
                            break
                        }
                    }
                }
                // Radar deliberately retains sparse lower instrument ticks; its
                // upper acquisition trace should span most of the width.
                let minimum = style == .radar && startY == 88 ? 70 : 250
                #expect(litColumns > minimum, "\(style), y=\(startY): insufficient edge coverage")
            }
        }
    }
}
