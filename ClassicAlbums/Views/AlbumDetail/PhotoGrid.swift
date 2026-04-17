import SwiftUI
import Photos
import UniformTypeIdentifiers

struct PhotoGrid: View {
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

    @State private var hasScrolledInitially = false
    @State private var scrollPosition: String?

    @State private var draggedID: String?
    @State private var hoveredID: String?
    @State private var postDropOrder: [String]?
    @State private var justMovedID: String?

    private let spacing: CGFloat = 2

    var body: some View {
        let sourceIDs = makeSourceIDs()
        let assetsByID = makeAssetsByID()
        let baseIDs = (postDropOrder != nil && postDropOrder != sourceIDs) ? postDropOrder! : sourceIDs
        let order = makeDisplayOrder(from: baseIDs)
        let indexByID = makeIndexByID(sourceIDs: sourceIDs)

        GeometryReader { proxy in
            let width = proxy.size.width
            let cellSize = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)

            ScrollView {
                LazyVGrid(columns: gridItems, spacing: spacing) {
                    ForEach(order, id: \.self) { id in
                        if let asset = assetsByID[id] {
                            cell(
                                id: id,
                                asset: asset,
                                sourceIdx: indexByID[id] ?? 0,
                                cellSize: cellSize
                            )
                        }
                    }
                    if let trailingAddTap {
                        Button(action: trailingAddTap) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.secondarySystemFill))
                                .frame(width: cellSize, height: cellSize)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.system(size: 28, weight: .regular))
                                        .foregroundStyle(Color.accentColor)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(draggedID != nil ? .easeInOut(duration: 0.22) : nil, value: order)
                .scrollTargetLayout()
                .onDrop(
                    of: [.text],
                    delegate: ReorderDropDelegate(
                        cellSize: cellSize,
                        spacing: spacing,
                        columns: columns,
                        displayOrder: order,
                        draggedID: draggedID,
                        hoveredID: $hoveredID,
                        onDrop: { commitAndCleanup() }
                    )
                )
            }
            .scrollPosition(id: $scrollPosition)
            .onAppear {
                guard !hasScrolledInitially, assets.count > 0 else { return }
                hasScrolledInitially = true
                let targetIdx = scrollToIndexOnAppear ?? (scrollToBottomOnAppear ? assets.count - 1 : nil)
                if let targetIdx, targetIdx >= 0, targetIdx < assets.count {
                    let id = assets.object(at: targetIdx).localIdentifier
                    DispatchQueue.main.async {
                        scrollPosition = id
                    }
                }
            }
            .onChange(of: scrollPosition) { _, newID in
                visibleTopIndex?.wrappedValue = newID.flatMap { indexByID[$0] }
            }
            .simultaneousGesture(
                MagnifyGesture()
                    .onEnded { value in
                        let scale = value.magnification
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if scale < 0.9 && columns == 3 {
                                columns = 5
                            } else if scale > 1.1 && columns == 5 {
                                columns = 3
                            }
                        }
                    }
            )
            .onDrop(of: [.text], isTargeted: nil) { _ in
                commitAndCleanup()
                return true
            }
            .task(id: sourceIDs) {
                if postDropOrder == sourceIDs {
                    postDropOrder = nil
                }
            }
        }
    }

    @ViewBuilder
    private func cell(id: String, asset: PHAsset, sourceIdx: Int, cellSize: CGFloat) -> some View {
        let selected = selectedIDs.contains(id)
        let isBeingDragged = (draggedID == id)
        let base = PhotoGridCell(
            asset: asset,
            size: cellSize,
            isSelecting: isSelecting,
            isSelected: selected
        )
        .contentShape(Rectangle())
        .opacity(isBeingDragged ? 0.3 : 1.0)
        .onTapGesture {
            if isSelecting {
                onToggleSelection(asset)
            } else {
                onSelect(sourceIdx)
            }
        }

        if isReorderable {
            base
                .onDrag {
                    DispatchQueue.main.async {
                        if justMovedID == id {
                            return
                        }
                        draggedID = id
                        hoveredID = id
                    }
                    return NSItemProvider(object: id as NSString)
                }
        } else {
            base
        }
    }

    private func commitAndCleanup() {
        let src = draggedID
        let dst = hoveredID
        guard let src, let dst, src != dst else {
            draggedID = nil
            hoveredID = nil
            return
        }
        let sourceIDs = makeSourceIDs()
        let isMultiMove = isSelecting && selectedIDs.contains(src) && selectedIDs.count > 1
        if isMultiMove, selectedIDs.contains(dst) {
            draggedID = nil
            hoveredID = nil
            return
        }
        if isMultiMove {
            let groupIDs = sourceIDs.filter { selectedIDs.contains($0) }
            var newOrder = sourceIDs.filter { !selectedIDs.contains($0) }
            if let newDstIdx = newOrder.firstIndex(of: dst) {
                newOrder.insert(contentsOf: groupIDs, at: newDstIdx)
                postDropOrder = newOrder
            }
            draggedID = nil
            hoveredID = nil
            justMovedID = src
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(3000))
                if justMovedID == src {
                    justMovedID = nil
                }
            }
            onMoveAssets(groupIDs, dst)
            return
        }
        if let srcIdx = sourceIDs.firstIndex(of: src),
           let dstIdx = sourceIDs.firstIndex(of: dst) {
            var newOrder = sourceIDs
            newOrder.remove(at: srcIdx)
            let insertAt = min(dstIdx, newOrder.count)
            newOrder.insert(src, at: insertAt)
            postDropOrder = newOrder
        }
        draggedID = nil
        hoveredID = nil
        justMovedID = src
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3000))
            if justMovedID == src {
                justMovedID = nil
            }
        }
        onMoveAsset(src, dst)
    }

    private func makeSourceIDs() -> [String] {
        (0..<assets.count).map { assets.object(at: $0).localIdentifier }
    }

    private func makeAssetsByID() -> [String: PHAsset] {
        var dict: [String: PHAsset] = [:]
        dict.reserveCapacity(assets.count)
        for i in 0..<assets.count {
            let a = assets.object(at: i)
            dict[a.localIdentifier] = a
        }
        return dict
    }

    private func makeIndexByID(sourceIDs: [String]) -> [String: Int] {
        var dict: [String: Int] = [:]
        dict.reserveCapacity(sourceIDs.count)
        for (i, id) in sourceIDs.enumerated() {
            dict[id] = i
        }
        return dict
    }

    private func makeDisplayOrder(from sourceIDs: [String]) -> [String] {
        guard let draggedID, let hoveredID, draggedID != hoveredID,
              let srcIdx = sourceIDs.firstIndex(of: draggedID),
              let dstIdx = sourceIDs.firstIndex(of: hoveredID)
        else { return sourceIDs }
        var result = sourceIDs
        result.remove(at: srcIdx)
        let insertAt = min(dstIdx, result.count)
        result.insert(draggedID, at: insertAt)
        return result
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let cellSize: CGFloat
    let spacing: CGFloat
    let columns: Int
    let displayOrder: [String]
    let draggedID: String?
    @Binding var hoveredID: String?
    let onDrop: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragged = draggedID else { return DropProposal(operation: .move) }
        let stride = cellSize + spacing
        let col = max(0, min(columns - 1, Int(info.location.x / stride)))
        let row = max(0, Int(info.location.y / stride))
        let index = row * columns + col
        let clamped = min(index, displayOrder.count - 1)
        guard clamped >= 0 else { return DropProposal(operation: .move) }
        let id = displayOrder[clamped]
        if id != dragged && hoveredID != id {
            hoveredID = id
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
        return true
    }

    func dropExited(info: DropInfo) {}
}
