import SwiftUI
import Photos

struct PhotoGridCellView: View {
    let asset: PHAsset
    let image: UIImage?
    let size: CGFloat
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Color(.secondarySystemBackground)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .overlay(alignment: .bottomLeading) {
            if asset.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelecting {
                selectionIndicator
                    .padding(6)
            } else if asset.mediaType == .video {
                Text(formattedDuration(asset.duration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(6)
            }
        }
        .scaleEffect(isSelecting && isSelected ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.accentColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
