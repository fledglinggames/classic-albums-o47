import UIKit
import Photos
import AVFoundation

@MainActor
final class ImageService {
    static let shared = ImageService()

    let caching = PHCachingImageManager()

    static let albumCover: CGSize = canonical(side: 360)
    static let gridLarge: CGSize = canonical(side: 360)
    static let gridSmall: CGSize = canonical(side: 200)

    static var screenSize: CGSize {
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let longest = max(bounds.width, bounds.height) * scale
        return CGSize(width: longest, height: longest)
    }

    private static func canonical(side: CGFloat) -> CGSize {
        let scale = UIScreen.main.scale
        let px = side * scale
        return CGSize(width: px, height: px)
    }

    static func gridTargetSize(forCellPoints cellPoints: CGFloat) -> CGSize {
        cellPoints <= 110 ? gridSmall : gridLarge
    }

    private init() {
        caching.allowsCachingHighQualityImages = false
    }

    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        caching.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        caching.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCachingAll() {
        caching.stopCachingImagesForAllAssets()
    }

    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let id = caching.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { @Sendable image, info in
                if let image {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func requestDisplayImage(
        for asset: PHAsset,
        targetSize: CGSize = ImageService.screenSize
    ) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let id = caching.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { @Sendable image, info in
                if let image {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func requestFullResolutionImage(for asset: PHAsset) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            let id = caching.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { @Sendable image, info in
                if let image {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func requestOriginalData(for asset: PHAsset) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.version = .original
            let id = caching.requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { @Sendable data, _, _, _ in
                if let data {
                    continuation.yield(data)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func requestLivePhoto(
        for asset: PHAsset,
        targetSize: CGSize = ImageService.screenSize
    ) -> AsyncStream<PHLivePhoto> {
        AsyncStream { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            let id = caching.requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { @Sendable result, info in
                if let result {
                    continuation.yield(result)
                }
                let isDegraded = (info?[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func requestPlayerItem(for asset: PHAsset) -> AsyncStream<AVPlayerItem> {
        AsyncStream { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            let id = caching.requestPlayerItem(
                forVideo: asset,
                options: options
            ) { @Sendable item, _ in
                if let item {
                    continuation.yield(item)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable [caching] _ in
                caching.cancelImageRequest(id)
            }
        }
    }

    func albumCoverAsset(for album: Album) -> PHAsset? {
        let options = PHFetchOptions()
        options.fetchLimit = 1
        if album.isSmartAlbum {
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        }
        let assets = PHAsset.fetchAssets(in: album.collection, options: options)
        return assets.firstObject
    }
}
