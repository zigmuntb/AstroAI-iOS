//
//  ImageStorageManager.swift
//  AstroAI
//

import UIKit

enum ImageStorageError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This file can't be used as a photo."
        }
    }
}

protocol ImageStorageManaging {
    func load(_ name: String) -> Data?
    /// Downscales the image and stores it as JPEG. Returns the stored data.
    func save(_ data: Data, as name: String) throws -> Data
    func remove(_ name: String)
}

/// Stores images as files in the app's Documents directory.
/// Later the same data can be uploaded to Supabase Storage.
final class ImageStorageManager: ImageStorageManaging {
    private let directory: URL
    private let maxDimension: CGFloat

    init(
        directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
        maxDimension: CGFloat = 512
    ) {
        self.directory = directory
        self.maxDimension = maxDimension
    }

    func load(_ name: String) -> Data? {
        try? Data(contentsOf: url(for: name))
    }

    func save(_ data: Data, as name: String) throws -> Data {
        guard let image = UIImage(data: data),
              let jpeg = resized(image).jpegData(compressionQuality: 0.85) else {
            throw ImageStorageError.invalidImage
        }
        try jpeg.write(to: url(for: name), options: .atomic)
        return jpeg
    }

    func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }

    // MARK: - Private

    private func url(for name: String) -> URL {
        directory.appendingPathComponent("\(name).jpg")
    }

    private func resized(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxDimension else { return image }
        let scale = maxDimension / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
