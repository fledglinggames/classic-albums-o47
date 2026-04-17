import UIKit
import Photos

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 500
    }

    func image(for album: Album, size: CGSize, skipCache: Bool = false) async -> UIImage? {
        let key = album.id as NSString
        if !skipCache, let cached = cache.object(forKey: key) { return cached }

        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        if album.isSmartAlbum {
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        }
        let assets = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
        guard let asset = assets.firstObject else {
            cache.removeObject(forKey: key)
            return nil
        }

        let image = await requestImage(for: asset, size: size)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    func invalidateAlbumCovers() {
        cache.removeAllObjects()
    }

    func image(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let px = Int(size.width.rounded())
        let key = "asset:\(asset.localIdentifier):\(px)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image = await requestImage(for: asset, size: size)
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    private func requestImage(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { @Sendable image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
