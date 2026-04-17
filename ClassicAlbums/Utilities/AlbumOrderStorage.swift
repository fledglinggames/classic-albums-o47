import Foundation

enum AlbumOrderStorage {
    private static let key = "myAlbumsOrder"

    static func loadOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func saveOrder(_ order: [String]) {
        UserDefaults.standard.set(order, forKey: key)
    }
}
