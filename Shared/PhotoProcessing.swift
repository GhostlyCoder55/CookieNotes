//
//  PhotoProcessing.swift
//  CookieNotes
//

import ImageIO
import UIKit

struct StoredPhoto: Equatable, Sendable {
    var imageData: Data
    var thumbnailData: Data
}

/// Downscales dish photos before they are stored so the library stays small.
enum PhotoProcessing {
    static let fullMaxPixel: CGFloat = 1_600
    static let thumbnailMaxPixel: CGFloat = 480

    static func makeStoredPhoto(from data: Data) -> StoredPhoto? {
        guard !data.isEmpty,
              let full = jpeg(from: data, maxPixel: fullMaxPixel, quality: 0.82),
              let thumbnail = jpeg(from: data, maxPixel: thumbnailMaxPixel, quality: 0.7) else {
            return nil
        }
        return StoredPhoto(imageData: full, thumbnailData: thumbnail)
    }

    private static func jpeg(from data: Data, maxPixel: CGFloat, quality: CGFloat) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }
}
