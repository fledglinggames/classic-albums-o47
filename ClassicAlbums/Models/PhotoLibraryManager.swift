import Photos
import Observation
import UIKit

@Observable
@MainActor
final class PhotoLibraryManager: NSObject, PHPhotoLibraryChangeObserver {
    var authorizationStatus: PHAuthorizationStatus
    var recents: Album?
    var favorites: Album?
    var hidden: Album?
    var userAlbums: [Album] = []
    var mediaTypeAlbums: [MediaTypeAlbum] = []
    var libraryChangeCount: Int = 0

    override init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.libraryChangeCount &+= 1
        }
    }

    func refreshAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized {
            fetchAlbums()
        }
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized {
            fetchAlbums()
        }
    }

    func fetchAlbums() {
        let recentsResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil
        )
        if let collection = recentsResult.firstObject {
            self.recents = Album(collection: collection)
        }

        let favoritesResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil
        )
        if let collection = favoritesResult.firstObject {
            self.favorites = Album(collection: collection)
        }

        let hiddenResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumAllHidden, options: nil
        )
        if let collection = hiddenResult.firstObject {
            self.hidden = Album(collection: collection)
        }

        let userResult = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: nil
        )
        var fetched: [Album] = []
        userResult.enumerateObjects { collection, _, _ in
            fetched.append(Album(collection: collection))
        }
        fetched.reverse()
        self.userAlbums = Self.order(albums: fetched, by: AlbumOrderStorage.loadOrder())

        let mediaTypeSpecs: [(String, String, PHAssetCollectionSubtype)] = [
            ("Videos", "video", .smartAlbumVideos),
            ("Selfies", "person.crop.square", .smartAlbumSelfPortraits),
            ("Live Photos", "livephoto", .smartAlbumLivePhotos),
            ("Portrait", "camera.filters", .smartAlbumDepthEffect),
            ("Panoramas", "pano", .smartAlbumPanoramas),
            ("Slo-mo", "slowmo", .smartAlbumSlomoVideos),
            ("Bursts", "square.stack.3d.down.right", .smartAlbumBursts),
            ("Screenshots", "camera.viewfinder", .smartAlbumScreenshots),
            ("Screen Recordings", "record.circle", .smartAlbumScreenRecordings),
            ("Animated", "square.stack.3d.forward.dottedline", .smartAlbumAnimated),
        ]
        self.mediaTypeAlbums = mediaTypeSpecs.compactMap { label, icon, subtype in
            let result = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil
            )
            guard let collection = result.firstObject else { return nil }
            return MediaTypeAlbum(label: label, iconName: icon, album: Album(collection: collection))
        }
    }

    @discardableResult
    func createAlbum(named name: String) async throws -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var order = AlbumOrderStorage.loadOrder()
        if order.isEmpty {
            order = userAlbums.map { $0.id }
        }

        nonisolated(unsafe) var placeholderID: String?
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: trimmed)
            placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
        }
        if let placeholderID {
            order.insert(placeholderID, at: 0)
            AlbumOrderStorage.saveOrder(order)
        }
        fetchAlbums()
        return placeholderID
    }

    func resetAlbumOrderToSystem() {
        let userResult = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: nil
        )
        var iosOrder: [String] = []
        userResult.enumerateObjects { collection, _, _ in
            iosOrder.append(collection.localIdentifier)
        }
        AlbumOrderStorage.saveOrder(iosOrder.reversed())
        fetchAlbums()
    }

    func renameAlbum(_ album: Album, to newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let collection = album.collection
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.title = trimmed
        }
        fetchAlbums()
    }

    func deleteAlbum(_ album: Album) async throws {
        let collection = album.collection
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
        }
        var order = AlbumOrderStorage.loadOrder()
        order.removeAll { $0 == album.id }
        AlbumOrderStorage.saveOrder(order)
        fetchAlbums()
    }

    func addAssets(_ assets: [PHAsset], to album: Album) async throws {
        let collection = album.collection
        let assetsCopy = assets
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.addAssets(assetsCopy as NSFastEnumeration)
        }
        fetchAlbums()
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        let assetsCopy = assets
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.deleteAssets(assetsCopy as NSArray)
        }
        fetchAlbums()
    }

    func setFavorite(_ asset: PHAsset, isFavorite: Bool) async throws {
        let assetCopy = asset
        let value = isFavorite
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetChangeRequest(for: assetCopy)
            request.isFavorite = value
        }
    }

    func setHidden(_ asset: PHAsset, isHidden: Bool) async throws {
        let assetCopy = asset
        let value = isHidden
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetChangeRequest(for: assetCopy)
            request.isHidden = value
        }
    }

    func duplicateAsset(from image: UIImage) async throws {
        let imageCopy = image
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.creationRequestForAsset(from: imageCopy)
        }
    }

    func adjustCreationDate(_ asset: PHAsset, to newDate: Date) async throws {
        let assetCopy = asset
        let dateCopy = newDate
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetChangeRequest(for: assetCopy)
            request.creationDate = dateCopy
        }
    }

    func moveAsset(sourceID: String, beforeID: String, in album: Album) async throws {
        let collection = album.collection
        let srcID = sourceID
        let dstID = beforeID
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let fetched = PHAsset.fetchAssets(in: collection, options: nil)
            var srcIdx = NSNotFound
            var dstIdx = NSNotFound
            fetched.enumerateObjects { asset, i, stop in
                if asset.localIdentifier == srcID { srcIdx = i }
                if asset.localIdentifier == dstID { dstIdx = i }
                if srcIdx != NSNotFound && dstIdx != NSNotFound {
                    stop.pointee = true
                }
            }
            guard srcIdx != NSNotFound, dstIdx != NSNotFound, srcIdx != dstIdx else { return }
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.moveAssets(at: IndexSet(integer: srcIdx), to: dstIdx)
        }
        fetchAlbums()
    }

    func moveAssets(sourceIDs: [String], beforeID: String, in album: Album) async throws {
        let collection = album.collection
        let srcIDsSet = Set(sourceIDs)
        let dstID = beforeID
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let fetched = PHAsset.fetchAssets(in: collection, options: nil)
            var srcIdxSet = IndexSet()
            var dstIdx = NSNotFound
            fetched.enumerateObjects { asset, i, _ in
                let id = asset.localIdentifier
                if srcIDsSet.contains(id) { srcIdxSet.insert(i) }
                if id == dstID { dstIdx = i }
            }
            guard !srcIdxSet.isEmpty, dstIdx != NSNotFound, !srcIdxSet.contains(dstIdx) else { return }
            let lessThanDst = srcIdxSet.filter { $0 < dstIdx }.count
            let adjustedDst = dstIdx - lessThanDst
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.moveAssets(at: srcIdxSet, to: adjustedDst)
        }
        fetchAlbums()
    }

    func removeAssets(_ assets: [PHAsset], from album: Album) async throws {
        let collection = album.collection
        let assetsCopy = assets
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCollectionChangeRequest(for: collection)
            request?.removeAssets(assetsCopy as NSFastEnumeration)
        }
        fetchAlbums()
    }

    static func anyAssetInUserAlbum(_ assets: [PHAsset]) -> Bool {
        for asset in assets {
            let result = PHAssetCollection.fetchAssetCollectionsContaining(
                asset, with: .album, options: nil
            )
            var found = false
            result.enumerateObjects { collection, _, stop in
                if collection.assetCollectionSubtype == .albumRegular {
                    found = true
                    stop.pointee = true
                }
            }
            if found { return true }
        }
        return false
    }

    private static func order(albums: [Album], by savedOrder: [String]) -> [Album] {
        var byID: [String: Album] = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        var result: [Album] = []

        let unknown = albums.filter { !savedOrder.contains($0.id) }
        result.append(contentsOf: unknown)
        for a in unknown { byID.removeValue(forKey: a.id) }

        for id in savedOrder {
            if let a = byID.removeValue(forKey: id) {
                result.append(a)
            }
        }
        return result
    }
}
