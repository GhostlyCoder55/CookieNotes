//
//  ImageCaches.swift
//  CookieNotes
//

import ImageIO
import SwiftUI
import UIKit

/// Remote images for Discover. `AsyncImage` refetches and re-decodes on every scroll-in;
/// this keeps downsampled bitmaps in memory and the raw bytes in a disk-backed URLCache.
final class RemoteImageLoader: @unchecked Sendable {
    static let shared = RemoteImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memory.totalCostLimit = 60 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    private static func key(_ url: URL, _ maxPixel: CGFloat) -> String {
        "\(url.absoluteString)#\(Int(maxPixel))"
    }

    func cachedImage(for url: URL, maxPixel: CGFloat) -> UIImage? {
        memory.object(forKey: Self.key(url, maxPixel) as NSString)
    }

    func image(for url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = Self.key(url, maxPixel)
        if let hit = memory.object(forKey: key as NSString) { return hit }

        // Detached so a card scrolling away doesn't cancel a download another card will reuse.
        let task: Task<UIImage?, Never> = lock.withLock {
            if let running = inFlight[key] { return running }
            let created = Task.detached(priority: .userInitiated) { [session] () -> UIImage? in
                guard let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
                else { return nil }
                return ImageDownsampler.downsample(data, maxPixel: maxPixel)
            }
            inFlight[key] = created
            return created
        }

        let image = await task.value
        lock.withLock { inFlight[key] = nil }
        if let image {
            memory.setObject(image, forKey: key as NSString, cost: image.memoryCost)
        }
        return image
    }
}

/// Decoded local photos keyed by their bytes, so grids don't re-decode JPEGs on every render.
enum LocalImageCache {
    private static let memory: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()

    static func image(for data: Data, maxPixel: CGFloat? = nil) -> UIImage? {
        let key = data as NSData
        if let hit = memory.object(forKey: key) { return hit }
        let decoded: UIImage?
        if let maxPixel {
            decoded = ImageDownsampler.downsample(data, maxPixel: maxPixel)
        } else {
            decoded = UIImage(data: data)?.preparingForDisplay()
        }
        if let decoded {
            memory.setObject(decoded, forKey: key, cost: decoded.memoryCost)
        }
        return decoded
    }
}

enum ImageDownsampler {
    static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel)
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

/// Drop-in for the Discover `AsyncImage` usages, backed by `RemoteImageLoader`.
struct CachedRemoteImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    /// Longest edge in points; converted to pixels for the screen scale.
    var maxPointSize: CGFloat = 400
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false

    private var maxPixel: CGFloat { maxPointSize * max(displayScale, 1) }

    var body: some View {
        Group {
            if let image = image ?? url.flatMap({ RemoteImageLoader.shared.cachedImage(for: $0, maxPixel: maxPixel) }) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed || url == nil {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = RemoteImageLoader.shared.cachedImage(for: url, maxPixel: maxPixel)
            failed = false
            if image != nil { return }
            let loaded = await RemoteImageLoader.shared.image(for: url, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            image = loaded
            failed = loaded == nil
        }
    }
}
