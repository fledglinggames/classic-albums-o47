import SwiftUI
import Photos

struct PhotoInfoPanel: View {
    let asset: PHAsset
    @State private var filename: String = ""
    @State private var fileSize: Int64 = 0
    @State private var lensInfo: String = "No lens information"
    @State private var formatBadge: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateLine)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            if !filename.isEmpty {
                Text(filename)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(mediaTypeLabel)
                        .font(.system(size: 13, weight: .semibold))
                    if !formatBadge.isEmpty {
                        Text(formatBadge)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text(lensInfo)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text(resolutionLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .task(id: asset.localIdentifier) {
            await loadMetadata()
        }
    }

    private var dateLine: String {
        guard let date = asset.creationDate else { return "Unknown date" }
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let dateStr = date.formatted(.dateTime.month(.abbreviated).day().year())
        let timeStr = date.formatted(.dateTime.hour().minute())
        return "\(weekday) • \(dateStr) • \(timeStr)"
    }

    private var mediaTypeLabel: String {
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoScreenshot) { return "Screenshot" }
            if asset.mediaSubtypes.contains(.photoLive) { return "Live Photo" }
            return "Photo"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        default:
            return "Media"
        }
    }

    private var resolutionLine: String {
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000
        let mp = String(format: "%.1f MP", megapixels)
        let dims = "\(asset.pixelWidth) × \(asset.pixelHeight)"
        if fileSize > 0 {
            let fs = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            return "\(mp) • \(dims) • \(fs)"
        }
        return "\(mp) • \(dims)"
    }

    private func loadMetadata() async {
        let resources = PHAssetResource.assetResources(for: asset)
        if let primary = resources.first {
            filename = (primary.originalFilename as NSString).deletingPathExtension
            let ext = (primary.originalFilename as NSString).pathExtension.uppercased()
            formatBadge = ext
            if let size = primary.value(forKey: "fileSize") as? Int64 {
                fileSize = size
            } else if let size = primary.value(forKey: "fileSize") as? Int {
                fileSize = Int64(size)
            }
        }
    }
}
