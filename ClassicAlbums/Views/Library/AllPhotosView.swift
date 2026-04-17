import SwiftUI
import Photos

struct AllPhotosView: View {
    let allPhotos: PHFetchResult<PHAsset>
    var scrollToMonth: (year: Int, month: Int)? = nil

    struct ViewerSelection: Identifiable {
        let id: Int
    }

    @State private var columns: Int = GridColumnStorage.load(key: GridColumnStorage.libraryKey)
    @State private var viewerSelection: ViewerSelection?
    @State private var visibleIndex: Int?
    @State private var debouncedVisibleIndex: Int?

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showAddToAlbum = false
    @State private var isPreparingShare = false

    var body: some View {
        PhotoGrid(
            assets: allPhotos,
            columns: $columns,
            scrollToBottomOnAppear: scrollToMonth == nil,
            scrollToIndexOnAppear: monthScrollIndex,
            visibleTopIndex: $visibleIndex,
            isSelecting: isSelecting,
            selectedIDs: selectedIDs,
            onSelect: { idx in viewerSelection = ViewerSelection(id: idx) },
            onToggleSelection: { asset in toggleSelection(asset) }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(dateTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.25), radius: 3)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Cancel") { exitSelection() }
                } else {
                    Button("Select") { enterSelection() }
                }
            }
        }
        .preference(key: LibrarySelectionActiveKey.self, value: isSelecting)
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionToolbar
            }
        }
        .onChange(of: columns) { _, newValue in
            GridColumnStorage.save(newValue, key: GridColumnStorage.libraryKey)
        }
        .task(id: visibleIndex) {
            try? await Task.sleep(for: .milliseconds(80))
            if !Task.isCancelled {
                debouncedVisibleIndex = visibleIndex
            }
        }
        .fullScreenCover(item: $viewerSelection) { selection in
            PhotoViewerView(assets: allPhotos, selectedIndex: selection.id)
        }
        .sheet(isPresented: $showAddToAlbum) {
            AddToAlbumSheet(assets: selectedAssets) {
                exitSelection()
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
                context: .systemAlbum,
                onPerform: {
                    exitSelection()
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

    private var selectedAssets: [PHAsset] {
        var result: [PHAsset] = []
        allPhotos.enumerateObjects { asset, _, _ in
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

    private var monthScrollIndex: Int? {
        guard let target = scrollToMonth else { return nil }
        let cal = Calendar.current
        for i in 0..<allPhotos.count {
            let asset = allPhotos.object(at: i)
            guard let date = asset.creationDate else { continue }
            let c = cal.dateComponents([.year, .month], from: date)
            guard let y = c.year, let m = c.month else { continue }
            if y > target.year || (y == target.year && m >= target.month) {
                return i
            }
        }
        return nil
    }

    private var dateTitle: String {
        let idx = debouncedVisibleIndex ?? (allPhotos.count > 0 ? allPhotos.count - 1 : 0)
        guard idx < allPhotos.count else { return "" }
        guard let date = allPhotos.object(at: idx).creationDate else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
