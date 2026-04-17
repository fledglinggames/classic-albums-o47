import SwiftUI
import Photos

struct DeleteButton: View {
    enum Context {
        case systemAlbum
        case userAlbum(Album)
    }

    let assets: [PHAsset]
    let context: Context
    let onPerform: () -> Void

    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var showDialog = false
    @State private var anyInUserAlbum = false

    var body: some View {
        Button {
            if case .systemAlbum = context {
                anyInUserAlbum = PhotoLibraryManager.anyAssetInUserAlbum(assets)
            }
            showDialog = true
        } label: {
            Image(systemName: "trash")
        }
        .confirmationDialog(
            "",
            isPresented: $showDialog,
            titleVisibility: .hidden
        ) {
            dialogButtons
        } message: {
            if let message = dialogMessage {
                Text(message)
            }
        }
    }

    private var dialogMessage: String? {
        let n = assets.count
        switch context {
        case .systemAlbum:
            if n == 1 {
                return anyInUserAlbum
                    ? "This photo will also be deleted from one or more albums."
                    : nil
            } else {
                return anyInUserAlbum
                    ? "These photos will also be deleted from one or more albums."
                    : nil
            }
        case .userAlbum:
            return n == 1
                ? "Do you want to delete this photo or remove it from this album?"
                : "Do you want to delete these photos or remove them from this album?"
        }
    }

    @ViewBuilder
    private var dialogButtons: some View {
        let n = assets.count
        switch context {
        case .systemAlbum:
            Button(n == 1 ? "Delete Photo" : "Delete \(n) Photos", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        case .userAlbum(let album):
            Button("Remove from Album") {
                performRemove(from: album)
            }
            Button(n == 1 ? "Delete from Library" : "Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func performDelete() {
        let toDelete = assets
        Task {
            try? await photoLibrary.deleteAssets(toDelete)
            onPerform()
        }
    }

    private func performRemove(from album: Album) {
        let toRemove = assets
        Task {
            try? await photoLibrary.removeAssets(toRemove, from: album)
            onPerform()
        }
    }
}
