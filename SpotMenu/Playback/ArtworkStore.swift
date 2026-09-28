import AppKit
import SwiftUI
import ImageIO

struct ArtworkPalette: Equatable {
    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
        var color: Color { Color(red: red, green: green, blue: blue) }
        func distance(to other: RGB) -> Double {
            pow(red - other.red, 2) + pow(green - other.green, 2) + pow(blue - other.blue, 2)
        }
    }
    let primary: RGB
    let secondary: RGB
    static let neutral = ArtworkPalette(primary: RGB(red: 0.30, green: 0.48, blue: 0.65),
                                        secondary: RGB(red: 0.55, green: 0.40, blue: 0.65))

    /// A 24x24 thumbnail and a small RGB histogram, once per image—not per frame.
    static func extract(from image: CGImage) -> ArtworkPalette {
        let side = 24
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return .neutral }
        struct Bucket { var r = 0.0; var g = 0.0; var b = 0.0; var weight = 0.0 }
        var buckets = [Int: Bucket]()
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            guard bytes[offset + 3] > 200 else { continue }
            let r = Double(bytes[offset]) / 255, g = Double(bytes[offset + 1]) / 255, b = Double(bytes[offset + 2]) / 255
            let high = max(r, g, b), low = min(r, g, b)
            guard high > 0.12 else { continue }
            let weight = 0.15 + (high - low) * 2
            let key = Int(r * 3) * 16 + Int(g * 3) * 4 + Int(b * 3)
            var bucket = buckets[key, default: Bucket()]
            bucket.r += r * weight; bucket.g += g * weight; bucket.b += b * weight; bucket.weight += weight
            buckets[key] = bucket
        }
        let sorted = buckets.sorted { $0.value.weight == $1.value.weight ? $0.key < $1.key : $0.value.weight > $1.value.weight }
        guard let first = sorted.first?.value else { return .neutral }
        let primary = RGB(red: first.r / first.weight, green: first.g / first.weight, blue: first.b / first.weight)
        let secondary = sorted.dropFirst().map { bucket in
            RGB(red: bucket.value.r / bucket.value.weight, green: bucket.value.g / bucket.value.weight, blue: bucket.value.b / bucket.value.weight)
        }.first(where: { $0.distance(to: primary) > 0.12 }) ?? primary
        return ArtworkPalette(primary: primary, secondary: secondary)
    }
}

struct ResolvedArtwork {
    let id = UUID()
    let identity: PlaybackTrackIdentity?
    let image: NSImage?
    let palette: ArtworkPalette
}

/// Shared by the floating player and Settings preview. Caches image + palette together.
final class ArtworkStore: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var palette = ArtworkPalette.neutral
    // Published atomically only after loading finishes (including missing/failed art).
    @Published private(set) var resolved = ResolvedArtwork(identity: nil, image: nil, palette: .neutral)
    private var request: Task<Void, Never>?
    private var key: String?
    private let cache = NSCache<NSString, Entry>()
    private final class Entry {
        let image: NSImage
        let palette: ArtworkPalette
        init(image: NSImage, palette: ArtworkPalette) { self.image = image; self.palette = palette }
    }

    init() { cache.countLimit = 20 }
    deinit { request?.cancel() }

    func update(url: URL?, fallback: NSImage?, identity: PlaybackTrackIdentity?) {
        let nextKey = "\(identity?.player ?? ""):\(identity?.track ?? ""):\(url?.absoluteString ?? "local"):art=\(fallback != nil)"
        let cacheKey = url?.absoluteString ?? nextKey
        guard nextKey != key else { return }
        key = nextKey
        request?.cancel()
        if let entry = cache.object(forKey: cacheKey as NSString) {
            image = entry.image; palette = entry.palette
            resolved = ResolvedArtwork(identity: identity, image: image, palette: palette)
            return
        }
        image = fallback
        palette = .neutral
        // Snapshot AppKit's local artwork on the main thread before decoding off-main.
        let localData = fallback?.tiffRepresentation
        if url == nil && localData == nil {
            resolved = ResolvedArtwork(identity: identity, image: image, palette: palette)
            return
        }
        request = Task { @MainActor [weak self] in
            defer {
                if !Task.isCancelled, let self, self.key == nextKey {
                    self.resolved = ResolvedArtwork(identity: identity, image: self.image, palette: self.palette)
                }
            }
            do {
                let data: Data
                if let url {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 3
                    let (download, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { return }
                    data = download
                } else if let localData { data = localData }
                else { return }
                guard !Task.isCancelled, data.count <= 12_000_000 else { return }
                let result = await Task.detached(priority: .utility) { () -> (CGImage, ArtworkPalette)? in
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 600,
                            kCGImageSourceCreateThumbnailWithTransform: true
                          ] as CFDictionary) else { return nil }
                    return (image, ArtworkPalette.extract(from: image))
                }.value
                guard !Task.isCancelled, let self, self.key == nextKey, let result else { return }
                let image = NSImage(cgImage: result.0, size: .zero)
                self.cache.setObject(Entry(image: image, palette: result.1), forKey: cacheKey as NSString)
                self.image = image
                self.palette = result.1
            } catch {
                guard !Task.isCancelled, let self, self.key == nextKey else { return }
                // Resolve once to the fallback, but let later metadata polls retry.
                // Repeated failures must not enqueue duplicate placeholder wipes.
                self.image = fallback
                self.palette = .neutral
                if self.resolved.identity != identity || self.resolved.image !== fallback {
                    self.resolved = ResolvedArtwork(identity: identity, image: fallback, palette: .neutral)
                }
                self.key = nil
            }
        }
    }
}

struct AlbumArtwork: View {
    @ObservedObject var store: ArtworkStore
    var body: some View { ArtworkImage(image: store.image) }
}

struct ArtworkImage: View {
    let image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").resizable().scaledToFit().padding(18).foregroundStyle(.secondary) }
        }
        .clipped()
    }
}
