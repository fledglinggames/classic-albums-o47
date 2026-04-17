import Foundation

enum LibraryViewMode: String, CaseIterable, Hashable {
    case years
    case months
    case allPhotos

    var title: String {
        switch self {
        case .years: return "Years"
        case .months: return "Months"
        case .allPhotos: return "All Photos"
        }
    }
}

enum LibraryViewModeStorage {
    private static let key = "libraryViewMode"

    static func load() -> LibraryViewMode {
        if let raw = UserDefaults.standard.string(forKey: key),
           let mode = LibraryViewMode(rawValue: raw) {
            return mode
        }
        return .allPhotos
    }

    static func save(_ mode: LibraryViewMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }
}

enum LibraryNavDestination: Hashable {
    case monthsInYear(Int)
    case allPhotosAtMonth(year: Int, month: Int)
}
