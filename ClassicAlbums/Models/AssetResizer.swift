import Foundation
import Photos
import UIKit
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

enum AssetResizeError: Error {
    case unsupportedMediaType
    case loadFailed
    case renderFailed
    case writeFailed
}

enum AssetResizer {
    static func resize(asset: PHAsset, factor: ResizeFactor) async throws {
        switch asset.playbackStyle {
        case .imageAnimated:
            try await resizeGIF(asset: asset, factor: factor)
        case .livePhoto:
            try await resizeLivePhoto(asset: asset, factor: factor)
        case .video, .videoLooping:
            try await resizeVideo(asset: asset, factor: factor)
        default:
            if isGIF(asset: asset) {
                try await resizeGIF(asset: asset, factor: factor)
            } else {
                try await resizeStillImage(asset: asset, factor: factor)
            }
        }
    }

    private static func isGIF(asset: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.contains { $0.uniformTypeIdentifier == UTType.gif.identifier }
    }

    // MARK: - Still image

    private static func resizeStillImage(asset: PHAsset, factor: ResizeFactor) async throws {
        let data = try await loadOriginalData(for: asset)
        guard let source = UIImage(data: data), let cg = source.cgImage else {
            throw AssetResizeError.loadFailed
        }

        let orientedSize = source.size
        let targetSize = CGSize(
            width: max(1, round(orientedSize.width * factor.multiplier)),
            height: max(1, round(orientedSize.height * factor.multiplier))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { ctx in
            ctx.cgContext.interpolationQuality = factor.isUpscale ? .none : .high
            let oriented = UIImage(cgImage: cg, scale: 1, orientation: source.imageOrientation)
            oriented.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        let outData: Data?
        let uti: String
        if factor.isUpscale {
            outData = rendered.pngData()
            uti = UTType.png.identifier
        } else {
            outData = rendered.jpegData(compressionQuality: 0.95)
            uti = UTType.jpeg.identifier
        }

        guard let outData else { throw AssetResizeError.renderFailed }
        let ext = factor.isUpscale ? "png" : "jpg"
        let url = try writeTemporary(data: outData, extension: ext)
        defer { try? FileManager.default.removeItem(at: url) }

        try await save(fileURL: url, uti: uti)
    }

    // MARK: - GIF

    private static func resizeGIF(asset: PHAsset, factor: ResizeFactor) async throws {
        let data = try await loadOriginalData(for: asset)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AssetResizeError.loadFailed
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw AssetResizeError.loadFailed }

        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + ".gif"
        )
        defer { try? FileManager.default.removeItem(at: outURL) }

        guard let destination = CGImageDestinationCreateWithURL(
            outURL as CFURL,
            UTType.gif.identifier as CFString,
            count,
            nil
        ) else { throw AssetResizeError.writeFailed }

        let sourceProps = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let loopCount: Int = {
            if let gifProps = sourceProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any],
               let n = gifProps[kCGImagePropertyGIFLoopCount] as? Int { return n }
            return 0
        }()
        let fileProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]
        ]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)

        for i in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let scaled = try scaleCGImage(frame, multiplier: factor.multiplier, upscale: factor.isUpscale)

            var frameProps: [CFString: Any] = [:]
            if let per = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gif = per[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                frameProps[kCGImagePropertyGIFDictionary] = gif
            }
            CGImageDestinationAddImage(destination, scaled, frameProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw AssetResizeError.writeFailed
        }

        try await save(fileURL: outURL, uti: UTType.gif.identifier)
    }

    private static func scaleCGImage(_ cg: CGImage, multiplier: CGFloat, upscale: Bool) throws -> CGImage {
        let width = max(1, Int(round(CGFloat(cg.width) * multiplier)))
        let height = max(1, Int(round(CGFloat(cg.height) * multiplier)))
        let colorSpace = cg.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { throw AssetResizeError.renderFailed }
        context.interpolationQuality = upscale ? .none : .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = context.makeImage() else { throw AssetResizeError.renderFailed }
        return out
    }

    // MARK: - Shared helpers

    private static func loadOriginalData(for asset: PHAsset) async throws -> Data {
        let assetCopy = asset
        let data: Data? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .original
            PHImageManager.default().requestImageDataAndOrientation(for: assetCopy, options: options) { @Sendable data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { throw AssetResizeError.loadFailed }
        return data
    }

    private static func writeTemporary(data: Data, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func save(fileURL: URL, uti: String) async throws {
        try await save(fileURL: fileURL, resourceType: .photo, uti: uti)
    }

    private static func save(fileURL: URL, resourceType: PHAssetResourceType, uti: String?) async throws {
        let url = fileURL
        let typeID = uti
        let rtype = resourceType
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            if let typeID { options.uniformTypeIdentifier = typeID }
            request.addResource(with: rtype, fileURL: url, options: options)
        }
    }

    // MARK: - Video

    private static func resizeVideo(asset: PHAsset, factor: ResizeFactor) async throws {
        let avAsset = try await loadAVAsset(for: asset)

        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw AssetResizeError.loadFailed
        }
        let (naturalSize, preferredTransform, nominalFrameRate) = try await videoTrack.load(
            .naturalSize, .preferredTransform, .nominalFrameRate
        )
        let duration = try await avAsset.load(.duration)

        let oriented = naturalSize.applying(preferredTransform)
        let orientedSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        let targetSize = CGSize(
            width: max(1, round(orientedSize.width * factor.multiplier) / 2) * 2,
            height: max(1, round(orientedSize.height * factor.multiplier) / 2) * 2
        )

        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AssetResizeError.renderFailed
        }
        try compVideo.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )

        let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first,
           let compAudio = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compAudio.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        }

        let scaleTransform = CGAffineTransform(scaleX: factor.multiplier, y: factor.multiplier)
        let finalTransform = preferredTransform.concatenating(scaleTransform)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        layerInstruction.setTransform(finalTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = targetSize
        let fps: Float = nominalFrameRate > 0 ? nominalFrameRate : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps.rounded()))

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        defer { try? FileManager.default.removeItem(at: outURL) }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AssetResizeError.renderFailed
        }
        exporter.videoComposition = videoComposition

        try await exporter.export(to: outURL, as: .mov)

        try await save(fileURL: outURL, resourceType: .video, uti: UTType.quickTimeMovie.identifier)
    }

    // MARK: - Live Photo

    private static func resizeLivePhoto(asset: PHAsset, factor: ResizeFactor) async throws {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let stillResource = resources.first(where: { $0.type == .photo }),
              let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
            throw AssetResizeError.loadFailed
        }

        let tmp = FileManager.default.temporaryDirectory
        let stem = UUID().uuidString
        let originalStillURL = tmp.appendingPathComponent("\(stem)-orig-still.heic")
        let originalVideoURL = tmp.appendingPathComponent("\(stem)-orig-paired.mov")
        let resizedStillURL = tmp.appendingPathComponent("\(stem)-out-still.heic")
        let resizedVideoURL = tmp.appendingPathComponent("\(stem)-out-paired.mov")
        defer {
            for url in [originalStillURL, originalVideoURL, resizedStillURL, resizedVideoURL] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try await writeResource(stillResource, to: originalStillURL)
        try await writeResource(videoResource, to: originalVideoURL)

        guard let contentID = readContentIdentifier(from: originalStillURL) else {
            throw AssetResizeError.loadFailed
        }

        try resizeLivePhotoStill(
            at: originalStillURL,
            to: resizedStillURL,
            multiplier: factor.multiplier,
            upscale: factor.isUpscale,
            contentID: contentID
        )

        try await resizeLivePhotoVideo(
            at: originalVideoURL,
            to: resizedVideoURL,
            multiplier: factor.multiplier,
            contentID: contentID
        )

        try await saveLivePhoto(stillURL: resizedStillURL, videoURL: resizedVideoURL)
    }

    private static func writeResource(_ resource: PHAssetResource, to url: URL) async throws {
        let resourceCopy = resource
        let urlCopy = url
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(
                for: resourceCopy,
                toFile: urlCopy,
                options: options
            ) { @Sendable error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func readContentIdentifier(from url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let makerApple = props[kCGImagePropertyMakerAppleDictionary] as? [String: Any],
              let contentID = makerApple["17"] as? String else {
            return nil
        }
        return contentID
    }

    private static func resizeLivePhotoStill(
        at inputURL: URL,
        to outputURL: URL,
        multiplier: CGFloat,
        upscale: Bool,
        contentID: String
    ) throws {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AssetResizeError.loadFailed
        }

        let scaled = try scaleCGImage(cg, multiplier: multiplier, upscale: upscale)

        var props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        var makerApple = (props[kCGImagePropertyMakerAppleDictionary] as? [String: Any]) ?? [:]
        makerApple["17"] = contentID
        props[kCGImagePropertyMakerAppleDictionary] = makerApple

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else { throw AssetResizeError.writeFailed }
        CGImageDestinationAddImage(destination, scaled, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw AssetResizeError.writeFailed
        }
    }

    private static func resizeLivePhotoVideo(
        at inputURL: URL,
        to outputURL: URL,
        multiplier: CGFloat,
        contentID: String
    ) async throws {
        let avAsset = AVURLAsset(url: inputURL)

        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw AssetResizeError.loadFailed
        }
        let (naturalSize, preferredTransform, nominalFrameRate) = try await videoTrack.load(
            .naturalSize, .preferredTransform, .nominalFrameRate
        )
        let duration = try await avAsset.load(.duration)

        let oriented = naturalSize.applying(preferredTransform)
        let orientedSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        let targetSize = CGSize(
            width: max(2, round(orientedSize.width * multiplier) / 2) * 2,
            height: max(2, round(orientedSize.height * multiplier) / 2) * 2
        )

        let composition = AVMutableComposition()
        guard let compVideo = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AssetResizeError.renderFailed
        }
        try compVideo.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )

        let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first,
           let compAudio = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compAudio.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        }

        let scaleTransform = CGAffineTransform(scaleX: multiplier, y: multiplier)
        let finalTransform = preferredTransform.concatenating(scaleTransform)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        layerInstruction.setTransform(finalTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = targetSize
        let fps: Float = nominalFrameRate > 0 ? nominalFrameRate : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps.rounded()))

        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = .quickTimeMetadataContentIdentifier
        metadataItem.value = contentID as NSString
        metadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AssetResizeError.renderFailed
        }
        exporter.videoComposition = videoComposition
        exporter.metadata = [metadataItem]

        try await exporter.export(to: outputURL, as: .mov)
    }

    private static func saveLivePhoto(stillURL: URL, videoURL: URL) async throws {
        let still = stillURL
        let video = videoURL
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: still, options: nil)
            request.addResource(with: .pairedVideo, fileURL: video, options: nil)
        }
    }

    private static func loadAVAsset(for asset: PHAsset) async throws -> AVAsset {
        let assetCopy = asset
        let boxed: AVAssetBox? = await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: assetCopy, options: options) { @Sendable avAsset, _, _ in
                if let avAsset {
                    continuation.resume(returning: AVAssetBox(asset: avAsset))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        guard let boxed else { throw AssetResizeError.loadFailed }
        return boxed.asset
    }
}

private struct AVAssetBox: @unchecked Sendable {
    let asset: AVAsset
}
