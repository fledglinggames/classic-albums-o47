import SwiftUI
import Photos

struct AlbumDetailView: View {
    let album: Album

    struct ViewerSelection: Identifiable {
        let id: Int
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var assets: PHFetchResult<PHAsset>?
    @State private var columns: Int = GridColumnStorage.load(key: GridColumnStorage.albumDetailKey)
    @State private var sortOrder: SortOrder
    @State private var viewerSelection: ViewerSelection?
    @State private var showingPhotoPicker = false

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showAddToAlbum = false
    @State private var isPreparingShare = false

    init(album: Album) {
        self.album = album
        _sortOrder = State(initialValue: SortOrderStorage.load(for: album))
    }

    var body: some View {
        Group {
            if let assets, assets.count > 0 {
                PhotoGrid(
                    assets: assets,
                    columns: $columns,
                    scrollToBottomOnAppear: scrollsToBottom,
                    isSelecting: isSelecting,
                    selectedIDs: selectedIDs,
                    isReorderable: canReorder,
                    onSelect: { idx in viewerSelection = ViewerSelection(id: idx) },
                    onToggleSelection: { asset in toggleSelection(asset) },
                    onMoveAsset: { srcID, dstID in moveAsset(sourceID: srcID, beforeID: dstID) },
                    onMoveAssets: { srcIDs, dstID in moveAssets(sourceIDs: srcIDs, beforeID: dstID) },
                    trailingAddTap: (!album.isSmartAlbum && !isSelecting)
                        ? { showingPhotoPicker = true }
                        : nil
                )
            } else if assets != nil {
                if album.isSmartAlbum {
                    emptyState
                } else {
                    emptyUserAlbumGrid
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(currentAlbum.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { exitSelection() }
                }
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !album.isSmartAlbum {
                        AlbumActionMenu(
                            album: album,
                            sortOrder: $sortOrder,
                            onAddPhotos: { showingPhotoPicker = true },
                            onAlbumDeleted: { dismiss() }
                        )
                    }
                    Button("Select") { enterSelection() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionToolbar
            }
        }
        .task(id: sortOrder) {
            assets = fetchAssets()
        }
        .onChange(of: columns) { _, newValue in
            GridColumnStorage.save(newValue, key: GridColumnStorage.albumDetailKey)
        }
        .onChange(of: photoLibrary.userAlbums) { _, _ in
            if !album.isSmartAlbum,
               !photoLibrary.userAlbums.contains(where: { $0.id == album.id }) {
                dismiss()
                return
            }
            assets = fetchAssets()
        }
        .onChange(of: photoLibrary.libraryChangeCount) { _, _ in
            assets = fetchAssets()
        }
        .fullScreenCover(item: $viewerSelection) { selection in
            if let assets {
                PhotoViewerView(
                    assets: assets,
                    selectedIndex: selection.id,
                    albumContext: album.isSmartAlbum ? .systemAlbum : .userAlbum(currentAlbum)
                )
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView(targetAlbum: album) {
                assets = fetchAssets()
            }
        }
        .sheet(isPresented: $showAddToAlbum) {
            AddToAlbumSheet(assets: selectedAssets) {
                exitSelection()
                assets = fetchAssets()
            }
        }
        .overlay {
            if isPreparingShare {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
        }
    }

    private var selectionToolbar: some View {
        HStack {
            Button {
                prepareShare()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .disabled(selectedIDs.isEmpty)

            Spacer()

            Text(selectionCountLabel)
                .font(.system(size: 15, weight: .medium))

            Spacer()

            DeleteButton(
                assets: selectedAssets,
                context: album.isSmartAlbum ? .systemAlbum : .userAlbum(currentAlbum),
                onPerform: {
                    exitSelection()
                    assets = fetchAssets()
                }
            )
            .font(.system(size: 20))
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var selectionCountLabel: String {
        let n = selectedIDs.count
        if n == 0 { return "Select Photos" }
        return n == 1 ? "1 Photo Selected" : "\(n) Photos Selected"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Photos")
                .font(.system(size: 28, weight: .bold))
            Text("This album is empty.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyUserAlbumGrid: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let width = proxy.size.width
            let cellSize = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(
                                Color.secondary.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .frame(width: cellSize, height: cellSize)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var canReorder: Bool {
        !album.isSmartAlbum && isSelecting
    }

    private func moveAsset(sourceID: String, beforeID: String) {
        guard sourceID != beforeID else { return }
        if sortOrder != .custom {
            sortOrder = .custom
            SortOrderStorage.save(.custom, for: album)
        }
        Task {
            try? await photoLibrary.moveAsset(sourceID: sourceID, beforeID: beforeID, in: album)
        }
    }

    private func moveAssets(sourceIDs: [String], beforeID: String) {
        guard !sourceIDs.isEmpty, !sourceIDs.contains(beforeID) else { return }
        if sortOrder != .custom {
            sortOrder = .custom
            SortOrderStorage.save(.custom, for: album)
        }
        Task {
            try? await photoLibrary.moveAssets(sourceIDs: sourceIDs, beforeID: beforeID, in: album)
        }
    }

    private var scrollsToBottom: Bool {
        sortOrder == .oldest
    }

    private var currentAlbum: Album {
        photoLibrary.userAlbums.first { $0.id == album.id } ?? album
    }

    private var selectedAssets: [PHAsset] {
        guard let assets else { return [] }
        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if selectedIDs.contains(asset.localIdentifier) {
                result.append(asset)
            }
        }
        return result
    }

    private func enterSelection() {
        isSelecting = true
        selectedIDs = []
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs = []
    }

    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func prepareShare() {
        let toShare = selectedAssets
        guard !toShare.isEmpty else { return }
        isPreparingShare = true
        Task {
            let urls = await AssetImageLoader.exportToTemporaryFiles(toShare)
            await MainActor.run {
                isPreparingShare = false
                guard !urls.isEmpty else { return }
                let activity = AddToAlbumActivity {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showAddToAlbum = true
                    }
                }
                ShareSheetPresenter.present(items: urls, activities: [activity])
            }
        }
    }

    private func fetchAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        let sortKey = album.collection.assetCollectionSubtype == .smartAlbumUserLibrary
            ? "addedDate"
            : "creationDate"
        switch sortOrder {
        case .oldest:
            options.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: true)]
        case .newest:
            options.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]
        case .custom:
            options.sortDescriptors = nil
        }
        return PHAsset.fetchAssets(in: album.collection, options: options)
    }
}
