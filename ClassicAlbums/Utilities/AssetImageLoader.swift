import Photos
import UIKit

enum AssetImageLoader {
    static func exportToTemporaryFiles(_ assets: [PHAsset]) async -> [URL] {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current

        var urls: [URL] = []
        for asset in assets {
            let result: (Data, String)? = await withCheckedContinuation { continuation in
                var resumed = false
                manager.requestImageDataAndOrientation(
                    for: asset,
                    options: options
                ) { data, uti, _, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if isDegraded { return }
                    if !resumed {
                        resumed = true
                        if let data {
                            continuation.resume(returning: (data, uti ?? "public.jpeg"))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
            guard let (data, uti) = result else { continue }
            let ext = fileExtension(forUTI: uti)
            let name = (asset.value(forKey: "filename") as? String) ?? "IMG_\(UUID().uuidString).\(ext)"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? data.write(to: url)
            urls.append(url)
        }
        return urls
    }

    private static func fileExtension(forUTI uti: String) -> String {
        switch uti {
        case "public.heic": return "heic"
        case "public.png": return "png"
        case "public.jpeg", "public.jpg": return "jpg"
        default: return "jpg"
        }
    }

    static func loadHighQualityImages(from assets: [PHAsset]) async -> [UIImage] {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        var results: [UIImage] = []
        for asset in assets {
            let image: UIImage? = await withCheckedContinuation { continuation in
                var resumed = false
                manager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .default,
                    options: options
                ) { image, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if isDegraded { return }
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: image)
                    }
                }
            }
            if let image {
                results.append(image)
            }
        }
        return results
    }
}
