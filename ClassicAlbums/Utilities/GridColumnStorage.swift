import Foundation

enum GridColumnStorage {
    static let libraryKey = "libraryGridColumns"
    static let albumDetailKey = "albumDetailGridColumns"

    static func load(key: String, default defaultValue: Int = 3) -> Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        return (stored == 3 || stored == 5) ? stored : defaultValue
    }

    static func save(_ columns: Int, key: String) {
        UserDefaults.standard.set(columns, forKey: key)
    }
}
