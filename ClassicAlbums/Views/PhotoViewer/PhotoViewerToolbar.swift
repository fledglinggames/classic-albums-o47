import SwiftUI
import Photos

struct PhotoViewerToolbar: View {
    let asset: PHAsset
    let isFavorite: Bool
    let albumContext: DeleteButton.Context
    var onShare: () -> Void = {}
    var onToggleFavorite: () -> Void = {}
    var onToggleInfo: () -> Void = {}
    var onDeleteCompleted: () -> Void = {}

    var body: some View {
        HStack {
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22))
            }
            Spacer()
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22))
            }
            Spacer()
            Button(action: onToggleInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 22))
            }
            Spacer()
            DeleteButton(
                assets: [asset],
                context: albumContext,
                onPerform: onDeleteCompleted
            )
            .font(.system(size: 22))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
