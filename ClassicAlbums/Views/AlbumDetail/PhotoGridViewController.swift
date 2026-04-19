import UIKit
import SwiftUI
import Photos

final class PhotoGridViewController: UIViewController {

    enum Section: Hashable { case photos }

    enum Item: Hashable {
        case photo(id: String)
        case trailingAdd
    }

    var assets: PHFetchResult<PHAsset>?
    var assetsByID: [String: PHAsset] = [:]
    var orderedIDs: [String] = []
    var trailingAddEnabled: Bool = false

    var columns: Int = 3 {
        didSet {
            guard isViewLoaded, columns != oldValue else { return }
            collectionView.setCollectionViewLayout(makeLayout(), animated: true) { [weak self] _ in
                self?.requestVisibleImages()
            }
        }
    }

    var isSelecting: Bool = false {
        didSet {
            guard isViewLoaded, isSelecting != oldValue else { return }
            reconfigureVisibleCells()
        }
    }

    var selectedIDs: Set<String> = [] {
        didSet {
            guard isViewLoaded, selectedIDs != oldValue else { return }
            reconfigureVisibleCells()
        }
    }

    var isReorderable: Bool = false

    var onSelect: (Int) -> Void = { _ in }
    var onToggleSelection: (PHAsset) -> Void = { _ in }
    var onMoveAsset: (String, String) -> Void = { _, _ in }
    var onMoveAssets: ([String], String) -> Void = { _, _ in }
    var onTrailingAddTap: (() -> Void)?
    var onVisibleTopIndexChange: ((Int?) -> Void)?

    var pendingScrollToIndex: Int?
    var hasPerformedInitialScroll: Bool = false
    var lastReportedVisibleTop: Int? = -1

    private(set) var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let imageCache = NSCache<NSString, UIImage>()
    private var imageTasks: [String: Task<Void, Never>] = [:]
    private var lastPrefetchedTargetSize: CGSize = .zero
    private var pinchStartColumns: Int = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        imageCache.countLimit = 600

        let layout = makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureDataSource()

        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collectionView.addGestureRecognizer(pinch)

        applySnapshot(animatingDifferences: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasPerformedInitialScroll, let target = pendingScrollToIndex {
            performScroll(toIndex: target)
            hasPerformedInitialScroll = true
            pendingScrollToIndex = nil
        }
    }

    deinit {
        for task in imageTasks.values { task.cancel() }
    }

    func setAssets(_ assets: PHFetchResult<PHAsset>?) {
        self.assets = assets
        var byID: [String: PHAsset] = [:]
        var ids: [String] = []
        if let assets {
            byID.reserveCapacity(assets.count)
            ids.reserveCapacity(assets.count)
            for i in 0..<assets.count {
                let a = assets.object(at: i)
                let id = a.localIdentifier
                ids.append(id)
                byID[id] = a
            }
        }
        self.assetsByID = byID
        self.orderedIDs = ids
        if isViewLoaded {
            applySnapshot(animatingDifferences: false)
        }
    }

    func setTrailingAddEnabled(_ enabled: Bool) {
        guard enabled != trailingAddEnabled else { return }
        trailingAddEnabled = enabled
        if isViewLoaded {
            applySnapshot(animatingDifferences: false)
        }
    }

    func requestScrollToIndex(_ index: Int?) {
        guard let index, !hasPerformedInitialScroll else { return }
        pendingScrollToIndex = index
        if isViewLoaded, collectionView.bounds.width > 0 {
            performScroll(toIndex: index)
            hasPerformedInitialScroll = true
            pendingScrollToIndex = nil
        }
    }

    private func performScroll(toIndex index: Int) {
        guard index >= 0, index < orderedIDs.count else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
    }

    private func makeLayout() -> UICollectionViewLayout {
        let cols = max(1, columns)
        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(cols - 1)
        let widthFraction = 1.0 / CGFloat(cols)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(widthFraction),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(widthFraction)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: cols)
        group.interItemSpacing = .fixed(spacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        let layout = UICollectionViewCompositionalLayout(section: section)
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.contentInsetsReference = .none
        layout.configuration = config
        let _ = totalSpacing
        return layout
    }

    private func configureDataSource() {
        let photoRegistration = UICollectionView.CellRegistration<UICollectionViewCell, String> { [weak self] cell, _, id in
            guard let self, let asset = self.assetsByID[id] else { return }
            let cellSize = self.currentCellPointSize()
            let cached = self.imageCache.object(forKey: id as NSString)
            cell.contentConfiguration = UIHostingConfiguration {
                PhotoGridCellView(
                    asset: asset,
                    image: cached,
                    size: cellSize,
                    isSelecting: self.isSelecting,
                    isSelected: self.selectedIDs.contains(id)
                )
            }
            .margins(.all, 0)
            cell.backgroundConfiguration = .clear()
            if cached == nil {
                self.requestImage(for: asset)
            }
        }

        let trailingAddRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Void> { [weak self] cell, _, _ in
            guard let self else { return }
            let cellSize = self.currentCellPointSize()
            cell.contentConfiguration = UIHostingConfiguration {
                TrailingAddTile(size: cellSize) {
                    self.onTrailingAddTap?()
                }
            }
            .margins(.all, 0)
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .photo(let id):
                return collectionView.dequeueConfiguredReusableCell(using: photoRegistration, for: indexPath, item: id)
            case .trailingAdd:
                return collectionView.dequeueConfiguredReusableCell(using: trailingAddRegistration, for: indexPath, item: ())
            }
        }
    }

    private func applySnapshot(animatingDifferences: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.photos])
        snapshot.appendItems(orderedIDs.map { Item.photo(id: $0) }, toSection: .photos)
        if trailingAddEnabled {
            snapshot.appendItems([.trailingAdd], toSection: .photos)
        }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func reconfigureVisibleCells() {
        var snapshot = dataSource.snapshot()
        let visible = collectionView.indexPathsForVisibleItems
            .compactMap { dataSource.itemIdentifier(for: $0) }
        snapshot.reconfigureItems(visible)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func currentCellPointSize() -> CGFloat {
        let width = collectionView.bounds.width
        guard width > 0 else { return 100 }
        let spacing: CGFloat = 2
        let cols = CGFloat(max(1, columns))
        return (width - spacing * (cols - 1)) / cols
    }

    private func currentTargetPixelSize() -> CGSize {
        let pts = currentCellPointSize()
        return ImageService.gridTargetSize(forCellPoints: pts)
    }

    private func requestImage(for asset: PHAsset) {
        let id = asset.localIdentifier
        if imageTasks[id] != nil { return }
        let target = currentTargetPixelSize()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            for await image in ImageService.shared.requestThumbnail(for: asset, targetSize: target) {
                if Task.isCancelled { return }
                self.imageCache.setObject(image, forKey: id as NSString)
                self.applyImage(image, for: id)
            }
            self.imageTasks[id] = nil
        }
        imageTasks[id] = task
    }

    private func applyImage(_ image: UIImage, for id: String) {
        guard let indexPath = dataSource.indexPath(for: .photo(id: id)),
              let cell = collectionView.cellForItem(at: indexPath),
              let asset = assetsByID[id] else { return }
        let cellSize = currentCellPointSize()
        cell.contentConfiguration = UIHostingConfiguration {
            PhotoGridCellView(
                asset: asset,
                image: image,
                size: cellSize,
                isSelecting: isSelecting,
                isSelected: selectedIDs.contains(id)
            )
        }
        .margins(.all, 0)
    }

    private func requestVisibleImages() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard case .photo(let id) = dataSource.itemIdentifier(for: indexPath),
                  let asset = assetsByID[id] else { continue }
            if imageCache.object(forKey: id as NSString) == nil {
                requestImage(for: asset)
            }
        }
    }

    private func cancelImageTasks(forIDs ids: [String]) {
        for id in ids {
            imageTasks[id]?.cancel()
            imageTasks[id] = nil
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartColumns = columns
        case .ended, .cancelled:
            let scale = recognizer.scale
            var next = pinchStartColumns
            if scale < 0.9 && pinchStartColumns == 3 {
                next = 5
            } else if scale > 1.1 && pinchStartColumns == 5 {
                next = 3
            }
            if next != columns {
                onColumnsChanged?(next)
            }
        default:
            break
        }
    }

    var onColumnsChanged: ((Int) -> Void)?
}

extension PhotoGridViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .photo(let id):
            guard let asset = assetsByID[id] else { return }
            if isSelecting {
                onToggleSelection(asset)
            } else if indexPath.item < orderedIDs.count {
                onSelect(indexPath.item)
            }
        case .trailingAdd:
            onTrailingAddTap?()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var topItem = Int.max
        for ip in collectionView.indexPathsForVisibleItems where ip.item < orderedIDs.count {
            if ip.item < topItem { topItem = ip.item }
        }
        let topIDIndex: Int? = topItem == Int.max ? nil : topItem
        if topIDIndex != lastReportedVisibleTop {
            lastReportedVisibleTop = topIDIndex
            onVisibleTopIndexChange?(topIDIndex)
        }
    }
}

extension PhotoGridViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetsToPrefetch = indexPaths.compactMap { ip -> PHAsset? in
            guard case .photo(let id) = dataSource.itemIdentifier(for: ip) else { return nil }
            return assetsByID[id]
        }
        guard !assetsToPrefetch.isEmpty else { return }
        let target = currentTargetPixelSize()
        ImageService.shared.startCaching(assets: assetsToPrefetch, targetSize: target)
        lastPrefetchedTargetSize = target
        for asset in assetsToPrefetch {
            if imageCache.object(forKey: asset.localIdentifier as NSString) == nil {
                requestImage(for: asset)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetsToStop = indexPaths.compactMap { ip -> PHAsset? in
            guard case .photo(let id) = dataSource.itemIdentifier(for: ip) else { return nil }
            return assetsByID[id]
        }
        guard !assetsToStop.isEmpty else { return }
        let target = lastPrefetchedTargetSize == .zero ? currentTargetPixelSize() : lastPrefetchedTargetSize
        ImageService.shared.stopCaching(assets: assetsToStop, targetSize: target)
        cancelImageTasks(forIDs: assetsToStop.map { $0.localIdentifier })
    }
}

extension PhotoGridViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard isReorderable,
              case .photo(let id) = dataSource.itemIdentifier(for: indexPath) else { return [] }
        let provider = NSItemProvider(object: id as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = id
        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        true
    }
}

extension PhotoGridViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        isReorderable && session.localDragSession != nil
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard isReorderable else { return }
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        guard let item = coordinator.items.first,
              let srcID = item.dragItem.localObject as? String else { return }

        let destItem = dataSource.itemIdentifier(for: destinationIndexPath)
        let dstID: String
        switch destItem {
        case .photo(let id):
            dstID = id
        case .trailingAdd, .none:
            guard let lastID = orderedIDs.last else { return }
            dstID = lastID
        }
        guard srcID != dstID else { return }

        let isMultiMove = isSelecting && selectedIDs.contains(srcID) && selectedIDs.count > 1
        if isMultiMove {
            if selectedIDs.contains(dstID) { return }
            let groupIDs = orderedIDs.filter { selectedIDs.contains($0) }
            onMoveAssets(groupIDs, dstID)
        } else {
            onMoveAsset(srcID, dstID)
        }
    }
}

private struct TrailingAddTile: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.secondarySystemFill))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                }
        }
        .buttonStyle(.plain)
    }
}
