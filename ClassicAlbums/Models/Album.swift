import Photos

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let isSmartAlbum: Bool
    let subtype: PHAssetCollectionSubtype
    let collection: PHAssetCollection

    init(collection: PHAssetCollection) {
        self.id = collection.localIdentifier
        self.title = collection.localizedTitle ?? "Untitled"
        self.collection = collection
        self.isSmartAlbum = collection.assetCollectionType == .smartAlbum
        self.subtype = collection.assetCollectionSubtype
        self.count = PHAsset.fetchAssets(in: collection, options: nil).count
    }

    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.count == rhs.count
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MediaTypeAlbum: Identifiable {
    let label: String
    let iconName: String
    let album: Album
    var id: String { album.id }
}
