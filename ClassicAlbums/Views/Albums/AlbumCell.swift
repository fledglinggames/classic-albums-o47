import SwiftUI
import Photos

struct AlbumCell: View {
    let album: Album
    let thumbnailSize: CGFloat
    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnail
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(alignment: .bottomLeading) {
                    if album.subtype == .smartAlbumFavorites {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                            .padding(8)
                    }
                }
                .contentShape(Rectangle())

            Text(album.title)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(album.count)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(width: thumbnailSize, alignment: .leading)
        .task(id: "\(album.id):\(photoLibrary.libraryChangeCount)") {
            guard let cover = ImageService.shared.albumCoverAsset(for: album) else {
                image = nil
                return
            }
            let scale = UIScreen.main.scale
            let px = thumbnailSize * scale
            let target = CGSize(width: px, height: px)
            for await loaded in ImageService.shared.requestThumbnail(for: cover, targetSize: target) {
                if Task.isCancelled { return }
                image = loaded
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(.secondarySystemBackground)
        }
    }
}
