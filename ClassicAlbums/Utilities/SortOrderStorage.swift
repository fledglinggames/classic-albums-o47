import Foundation

enum SortOrderStorage {
    private static func key(for albumId: String) -> String {
        "albumSortOrder_\(albumId)"
    }

    static func load(for album: Album) -> SortOrder {
        if let raw = UserDefaults.standard.string(forKey: key(for: album.id)),
           let value = SortOrder(rawValue: raw) {
            return value
        }
        return album.isSmartAlbum ? .oldest : .custom
    }

    static func save(_ order: SortOrder, for album: Album) {
        UserDefaults.standard.set(order.rawValue, forKey: key(for: album.id))
    }
}
