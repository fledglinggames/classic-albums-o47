import SwiftUI
import Photos

struct AddToAlbumSheet: View {
    let assets: [PHAsset]
    let onComplete: () -> Void

    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateAlbum = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingCreateAlbum = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("New Album")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                Section {
                    ForEach(photoLibrary.userAlbums) { album in
                        Button {
                            add(to: album)
                        } label: {
                            HStack {
                                Text(album.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Text("\(album.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .createAlbumAlert(isPresented: $showingCreateAlbum)
        }
    }

    private func add(to album: Album) {
        let toAdd = assets
        Task {
            try? await photoLibrary.addAssets(toAdd, to: album)
            onComplete()
            dismiss()
        }
    }
}
