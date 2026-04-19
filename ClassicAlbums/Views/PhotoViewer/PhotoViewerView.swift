import SwiftUI
import Photos
import UIKit

struct PhotoViewerView: View {
    let assets: PHFetchResult<PHAsset>
    @State var selectedIndex: Int
    var albumContext: DeleteButton.Context = .systemAlbum

    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryManager.self) private var photoLibrary

    @State private var showChrome: Bool = true
    @State private var showInfoPanel: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var dismissDragOffset: CGSize = .zero

    @State private var currentAsset: PHAsset?
    @State private var currentIsFavorite: Bool = false
    @State private var isLoadingAction = false

    @State private var showingResizeDialog = false
    @State private var resizeTargetAsset: PHAsset?
    @State private var showingResizeUnsupported = false

    @State private var cachedAssets: [PHAsset] = []
    @State private var cachedFetchID: ObjectIdentifier?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                if !cachedAssets.isEmpty {
                    PhotoViewerPagedView(
                        assets: cachedAssets,
                        selectedIndex: $selectedIndex,
                        zoomScale: $zoomScale,
                        onSingleTap: { toggleChrome() }
                    )
                }
            }
            .ignoresSafeArea()
            .offset(y: dismissDragOffset.height)
            .opacity(dismissOpacity)
            .simultaneousGesture(dismissDrag)

            if showChrome {
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showChrome, let currentAsset {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if showInfoPanel {
                        PhotoInfoPanel(asset: currentAsset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    PhotoViewerToolbar(
                        asset: currentAsset,
                        isFavorite: currentIsFavorite,
                        albumContext: albumContext,
                        onShare: { shareCurrent(currentAsset) },
                        onToggleFavorite: { toggleFavorite(currentAsset) },
                        onToggleInfo: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showInfoPanel.toggle()
                            }
                        },
                        onDeleteCompleted: { dismiss() }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBarHidden(!showChrome)
        .task(id: ObjectIdentifier(assets)) {
            let newID = ObjectIdentifier(assets)
            guard newID != cachedFetchID else { return }
            cachedAssets = Self.buildAssetList(assets: assets)
            cachedFetchID = newID
            refreshCurrentAsset()
        }
        .onAppear {
            refreshCurrentAsset()
            setOrientation(mask: [.portrait, .landscapeLeft, .landscapeRight])
        }
        .onDisappear {
            setOrientation(mask: .portrait)
        }
        .onChange(of: selectedIndex) { _, _ in
            zoomScale = 1.0
            showInfoPanel = false
            refreshCurrentAsset()
        }
        .onChange(of: photoLibrary.libraryChangeCount) { _, _ in
            refreshCurrentAsset()
        }
        .overlay {
            if isLoadingAction {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
        }
        .confirmationDialog(
            "How do you want to resize?",
            isPresented: $showingResizeDialog,
            titleVisibility: .visible,
            presenting: resizeTargetAsset
        ) { asset in
            ForEach(ResizeFactor.allCases) { factor in
                Button(factor.label) { performResize(asset, factor: factor) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Resize not yet supported", isPresented: $showingResizeUnsupported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This media type is not supported by Duplicate With Resize.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 32) {
                Button("Edit") {
                    openPhotosApp()
                }
                .font(.system(size: 18))
                if let currentAsset {
                    MoreOptionsMenu(
                        onCopy: { copyToClipboard(currentAsset) },
                        onDuplicate: { duplicate(currentAsset) },
                        onDuplicateWithResize: { promptResize(currentAsset) },
                        onHide: { hide(currentAsset) },
                        onAdjustDate: { presentAdjustDate(currentAsset) }
                    )
                    .font(.system(size: 22))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func presentAdjustDate(_ asset: PHAsset) {
        let originalDate = asset.creationDate ?? Date()
        SheetPresenter.present {
            AdjustDateTimeSheet(originalDate: originalDate) { newDate in
                adjustDate(asset, to: newDate)
            }
        }
    }

    private func refreshCurrentAsset() {
        guard selectedIndex >= 0 else {
            currentAsset = nil
            currentIsFavorite = false
            return
        }
        let localID: String?
        if !cachedAssets.isEmpty, selectedIndex < cachedAssets.count {
            localID = cachedAssets[selectedIndex].localIdentifier
        } else if selectedIndex < assets.count {
            localID = assets.object(at: selectedIndex).localIdentifier
        } else {
            localID = nil
        }
        guard let id = localID else {
            currentAsset = nil
            currentIsFavorite = false
            return
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        currentAsset = result.firstObject
        currentIsFavorite = result.firstObject?.isFavorite ?? false
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showChrome.toggle()
            if !showChrome { showInfoPanel = false }
        }
    }

    private static func buildAssetList(assets: PHFetchResult<PHAsset>) -> [PHAsset] {
        var result: [PHAsset] = []
        result.reserveCapacity(assets.count)
        for i in 0..<assets.count {
            result.append(assets.object(at: i))
        }
        return result
    }

    private func openPhotosApp() {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }

    private func setOrientation(mask: UIInterfaceOrientationMask) {
        AppDelegate.allowedOrientations = mask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func toggleFavorite(_ asset: PHAsset) {
        let newValue = !asset.isFavorite
        currentIsFavorite = newValue
        Task {
            try? await photoLibrary.setFavorite(asset, isFavorite: newValue)
        }
    }

    private func shareCurrent(_ asset: PHAsset) {
        isLoadingAction = true
        Task {
            let urls = await AssetImageLoader.exportToTemporaryFiles([asset])
            await MainActor.run {
                isLoadingAction = false
                guard !urls.isEmpty else { return }
                let activity = AddToAlbumActivity { [photoLibrary] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentAddToAlbum(assets: [asset], photoLibrary: photoLibrary)
                    }
                }
                ShareSheetPresenter.present(items: urls, activities: [activity])
            }
        }
    }

    private func presentAddToAlbum(assets: [PHAsset], photoLibrary: PhotoLibraryManager) {
        SheetPresenter.present {
            AddToAlbumSheet(assets: assets, onComplete: {})
                .environment(photoLibrary)
        }
    }

    private func copyToClipboard(_ asset: PHAsset) {
        isLoadingAction = true
        Task {
            let images = await AssetImageLoader.loadHighQualityImages(from: [asset])
            await MainActor.run {
                if let image = images.first {
                    UIPasteboard.general.image = image
                }
                isLoadingAction = false
            }
        }
    }

    private func promptResize(_ asset: PHAsset) {
        resizeTargetAsset = asset
        showingResizeDialog = true
    }

    private func performResize(_ asset: PHAsset, factor: ResizeFactor) {
        isLoadingAction = true
        Task {
            do {
                try await AssetResizer.resize(asset: asset, factor: factor)
                await MainActor.run { isLoadingAction = false }
            } catch AssetResizeError.unsupportedMediaType {
                await MainActor.run {
                    isLoadingAction = false
                    showingResizeUnsupported = true
                }
            } catch {
                await MainActor.run { isLoadingAction = false }
            }
        }
    }

    private func duplicate(_ asset: PHAsset) {
        isLoadingAction = true
        Task {
            let images = await AssetImageLoader.loadHighQualityImages(from: [asset])
            if let image = images.first {
                try? await photoLibrary.duplicateAsset(from: image)
            }
            await MainActor.run {
                isLoadingAction = false
            }
        }
    }

    private func hide(_ asset: PHAsset) {
        Task {
            try? await photoLibrary.setHidden(asset, isHidden: true)
            await MainActor.run {
                dismiss()
            }
        }
    }

    private func adjustDate(_ asset: PHAsset, to newDate: Date) {
        Task {
            try? await photoLibrary.adjustCreationDate(asset, to: newDate)
        }
    }

    private var dismissOpacity: Double {
        let progress = min(1.0, abs(dismissDragOffset.height) / 300)
        return 1.0 - progress * 0.7
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard zoomScale == 1.0 else { return }
                guard value.translation.height > abs(value.translation.width) else { return }
                guard value.translation.height > 0 else { return }
                dismissDragOffset = CGSize(width: 0, height: value.translation.height)
            }
            .onEnded { value in
                guard zoomScale == 1.0 else { return }
                if value.translation.height > 120 &&
                   value.translation.height > abs(value.translation.width) {
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismissDragOffset = .zero
                    }
                }
            }
    }
}
