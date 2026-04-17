import SwiftUI
import Photos

struct AlbumsView: View {
    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var navigationPath = NavigationPath()
    @State private var showingCreateAlbum = false

    var body: some View {
        switch photoLibrary.authorizationStatus {
        case .authorized:
            authorizedContent
        case .limited, .denied, .restricted, .notDetermined:
            FullAccessRequiredView()
        @unknown default:
            FullAccessRequiredView()
        }
    }

    private var authorizedContent: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MyAlbumsSection(albums: myAlbumsAll)
                    MediaTypesSection(items: photoLibrary.mediaTypeAlbums)
                    UtilitiesSection()
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCreateAlbum = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: AlbumsNavDestination.self) { destination in
                switch destination {
                case .seeAll:
                    MyAlbumsSeeAllView()
                case .album(let album):
                    AlbumDetailView(album: album)
                }
            }
            .createAlbumAlert(isPresented: $showingCreateAlbum)
        }
        .task {
            if photoLibrary.userAlbums.isEmpty && photoLibrary.mediaTypeAlbums.isEmpty {
                photoLibrary.fetchAlbums()
            }
        }
        .onChange(of: photoLibrary.libraryChangeCount) { _, _ in
            ThumbnailCache.shared.invalidateAlbumCovers()
            photoLibrary.fetchAlbums()
        }
    }

    private var myAlbumsAll: [Album] {
        var result: [Album] = []
        if let r = photoLibrary.recents { result.append(r) }
        if let f = photoLibrary.favorites { result.append(f) }
        result.append(contentsOf: photoLibrary.userAlbums)
        return result
    }
}
