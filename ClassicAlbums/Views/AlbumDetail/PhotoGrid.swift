import SwiftUI
import Photos

struct PhotoGrid: UIViewControllerRepresentable {
    let assets: PHFetchResult<PHAsset>
    @Binding var columns: Int
    var scrollToBottomOnAppear: Bool = false
    var scrollToIndexOnAppear: Int? = nil
    var visibleTopIndex: Binding<Int?>? = nil
    var isSelecting: Bool = false
    var selectedIDs: Set<String> = []
    var isReorderable: Bool = false
    var onSelect: (Int) -> Void = { _ in }
    var onToggleSelection: (PHAsset) -> Void = { _ in }
    var onMoveAsset: (String, String) -> Void = { _, _ in }
    var onMoveAssets: ([String], String) -> Void = { _, _ in }
    var trailingAddTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> PhotoGridViewController {
        let vc = PhotoGridViewController()
        vc.columns = columns
        vc.isSelecting = isSelecting
        vc.selectedIDs = selectedIDs
        vc.isReorderable = isReorderable
        vc.setAssets(assets)
        vc.setTrailingAddEnabled(trailingAddTap != nil)
        let target = scrollToIndexOnAppear ?? (scrollToBottomOnAppear ? max(0, assets.count - 1) : nil)
        vc.requestScrollToIndex(target)
        wireCallbacks(vc: vc, context: context)
        context.coordinator.lastFetchID = ObjectIdentifier(assets)
        return vc
    }

    func updateUIViewController(_ vc: PhotoGridViewController, context: Context) {
        wireCallbacks(vc: vc, context: context)

        let newID = ObjectIdentifier(assets)
        if context.coordinator.lastFetchID != newID {
            vc.setAssets(assets)
            context.coordinator.lastFetchID = newID
        }
        vc.setTrailingAddEnabled(trailingAddTap != nil)
        vc.isReorderable = isReorderable
        vc.isSelecting = isSelecting
        vc.selectedIDs = selectedIDs
        vc.columns = columns
    }

    private func wireCallbacks(vc: PhotoGridViewController, context: Context) {
        vc.onSelect = onSelect
        vc.onToggleSelection = onToggleSelection
        vc.onMoveAsset = onMoveAsset
        vc.onMoveAssets = onMoveAssets
        vc.onTrailingAddTap = trailingAddTap
        let visibleBinding = visibleTopIndex
        vc.onVisibleTopIndexChange = { idx in
            visibleBinding?.wrappedValue = idx
        }
        vc.onColumnsChanged = { newValue in
            columns = newValue
        }
    }

    final class Coordinator {
        var lastFetchID: ObjectIdentifier?
    }
}
