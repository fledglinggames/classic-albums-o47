import SwiftUI

struct AlbumActionMenu: View {
    let album: Album
    @Binding var sortOrder: SortOrder
    var onAddPhotos: () -> Void
    var onAlbumDeleted: () -> Void

    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var showingRename = false
    @State private var showingDelete = false
    @State private var showingSortSheet = false
    @State private var renameText: String = ""

    var body: some View {
        Menu {
            Button {
                onAddPhotos()
            } label: {
                Label("Add Photos", systemImage: "photo.on.rectangle")
            }
            Button {
                showingSortSheet = true
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            Button {
                renameText = album.title
                showingRename = true
            } label: {
                Label("Rename Album", systemImage: "pencil")
            }
            Button(role: .destructive) {
                showingDelete = true
            } label: {
                Label("Delete Album", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .alert("Rename Album", isPresented: $showingRename) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { rename() }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new name for this album.")
        }
        .alert("Delete \"\(album.title)\"", isPresented: $showingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("Are you sure you want to delete the album \"\(album.title)\"? The photos will not be deleted.")
        }
        .confirmationDialog("Sort By:", isPresented: $showingSortSheet, titleVisibility: .visible) {
            Button {
                setSort(.custom)
            } label: {
                Text(sortOrder == .custom ? "✓ Custom Order" : "Custom Order")
            }
            Button {
                setSort(.oldest)
            } label: {
                Text(sortOrder == .oldest ? "✓ Oldest to Newest" : "Oldest to Newest")
            }
            Button {
                setSort(.newest)
            } label: {
                Text(sortOrder == .newest ? "✓ Newest to Oldest" : "Newest to Oldest")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func rename() {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        Task {
            do {
                try await photoLibrary.renameAlbum(album, to: newName)
            } catch {
                print("Error renaming album: \(error)")
            }
        }
    }

    private func delete() {
        Task {
            do {
                try await photoLibrary.deleteAlbum(album)
                onAlbumDeleted()
            } catch {
                print("Error deleting album: \(error)")
            }
        }
    }

    private func setSort(_ order: SortOrder) {
        sortOrder = order
        SortOrderStorage.save(order, for: album)
    }
}
