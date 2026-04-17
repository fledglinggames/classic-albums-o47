import SwiftUI
import UniformTypeIdentifiers

struct MyAlbumsSeeAllView: View {
    @Environment(PhotoLibraryManager.self) private var photoLibrary

    @State private var isEditing = false
    @State private var editedAlbums: [Album] = []
    @State private var draggedAlbum: Album?
    @State private var albumToDelete: Album?
    @State private var showingCreateAlbum = false

    private let horizontalPadding: CGFloat = 16
    private let columnSpacing: CGFloat = 16

    private var userAlbumsForDisplay: [Album] {
        isEditing ? editedAlbums : photoLibrary.userAlbums
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cellSize = (width - horizontalPadding * 2 - columnSpacing) / 2

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cellSize), spacing: columnSpacing),
                        GridItem(.fixed(cellSize), spacing: columnSpacing)
                    ],
                    alignment: .leading,
                    spacing: 20
                ) {
                    ForEach(systemAlbums) { album in
                        NavigationLink(value: AlbumsNavDestination.album(album)) {
                            AlbumCell(album: album, thumbnailSize: cellSize)
                                .opacity(0.85)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(userAlbumsForDisplay) { album in
                        userAlbumCell(album: album, cellSize: cellSize)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("My Albums")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button {
                        showingCreateAlbum = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        AlbumOrderStorage.saveOrder(editedAlbums.map { $0.id })
                        photoLibrary.fetchAlbums()
                        draggedAlbum = nil
                    } else {
                        editedAlbums = photoLibrary.userAlbums
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert(
            "Delete \"\(albumToDelete?.title ?? "")\"",
            isPresented: Binding(
                get: { albumToDelete != nil },
                set: { if !$0 { albumToDelete = nil } }
            ),
            presenting: albumToDelete
        ) { album in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await photoLibrary.deleteAlbum(album)
                }
            }
        } message: { album in
            Text("Are you sure you want to delete the album \"\(album.title)\"? The photos will not be deleted.")
        }
        .createAlbumAlert(isPresented: $showingCreateAlbum)
        .onChange(of: photoLibrary.userAlbums) { _, newValue in
            if isEditing {
                editedAlbums = newValue
            }
        }
    }

    @ViewBuilder
    private func userAlbumCell(album: Album, cellSize: CGFloat) -> some View {
        if isEditing {
            AlbumCell(album: album, thumbnailSize: cellSize)
                .contentShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    Button {
                        albumToDelete = album
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .font(.system(size: 24))
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    }
                    .offset(x: -8, y: -8)
                }
                .onDrag {
                    draggedAlbum = album
                    return NSItemProvider(object: album.id as NSString)
                }
                .onDrop(of: [.text], delegate: AlbumDropDelegate(
                    item: album,
                    items: $editedAlbums,
                    draggedItem: $draggedAlbum
                ))
        } else {
            NavigationLink(value: AlbumsNavDestination.album(album)) {
                AlbumCell(album: album, thumbnailSize: cellSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var systemAlbums: [Album] {
        var result: [Album] = []
        if let r = photoLibrary.recents { result.append(r) }
        if let f = photoLibrary.favorites { result.append(f) }
        return result
    }
}

private struct AlbumDropDelegate: DropDelegate {
    let item: Album
    @Binding var items: [Album]
    @Binding var draggedItem: Album?

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem.id != item.id else { return }
        guard let from = items.firstIndex(where: { $0.id == draggedItem.id }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[to].id != draggedItem.id {
            withAnimation(.default) {
                items.move(
                    fromOffsets: IndexSet(integer: from),
                    toOffset: to > from ? to + 1 : to
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        AlbumOrderStorage.saveOrder(items.map { $0.id })
        draggedItem = nil
        return true
    }
}
