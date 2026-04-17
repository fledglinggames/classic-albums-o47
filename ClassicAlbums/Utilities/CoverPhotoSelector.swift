import Photos
import Foundation

struct LibraryIndex {
    struct MonthKey: Hashable, Comparable {
        let year: Int
        let month: Int
        static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            return lhs.month < rhs.month
        }
    }

    let yearAssets: [Int: [PHAsset]]
    let monthAssets: [MonthKey: [PHAsset]]

    var years: [Int] {
        yearAssets.keys.sorted()
    }

    func months(inYear year: Int? = nil) -> [MonthKey] {
        let keys = monthAssets.keys
        if let year {
            return keys.filter { $0.year == year }.sorted()
        }
        return keys.sorted()
    }

    static func build(from fetchResult: PHFetchResult<PHAsset>) -> LibraryIndex {
        var yearMap: [Int: [PHAsset]] = [:]
        var monthMap: [MonthKey: [PHAsset]] = [:]
        let cal = Calendar.current
        fetchResult.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let components = cal.dateComponents([.year, .month], from: date)
            guard let year = components.year, let month = components.month else { return }
            yearMap[year, default: []].append(asset)
            monthMap[MonthKey(year: year, month: month), default: []].append(asset)
        }
        return LibraryIndex(yearAssets: yearMap, monthAssets: monthMap)
    }
}

enum CoverPhotoSelector {
    static func yearCover(year: Int, assets: [PHAsset], today: Date) -> PHAsset? {
        let cal = Calendar.current
        let todayComps = cal.dateComponents([.month, .day], from: today)
        guard let targetMonth = todayComps.month, let targetDay = todayComps.day else {
            return assets.first
        }

        var onAnchor: PHAsset?
        var firstAfter: PHAsset?
        var lastBefore: PHAsset?

        for asset in assets {
            guard let date = asset.creationDate else { continue }
            let c = cal.dateComponents([.month, .day], from: date)
            let m = c.month ?? 0
            let d = c.day ?? 0

            if m == targetMonth && d == targetDay {
                if onAnchor == nil { onAnchor = asset }
            } else if m > targetMonth || (m == targetMonth && d > targetDay) {
                if firstAfter == nil { firstAfter = asset }
            } else {
                lastBefore = asset
            }
        }

        return onAnchor ?? firstAfter ?? lastBefore
    }

    static func monthCover(assets: [PHAsset], today: Date) -> PHAsset? {
        let cal = Calendar.current
        let targetDay = cal.component(.day, from: today)

        var onAnchor: PHAsset?
        var firstAfter: PHAsset?
        var lastBefore: PHAsset?

        for asset in assets {
            guard let date = asset.creationDate else { continue }
            let day = cal.component(.day, from: date)

            if day == targetDay {
                if onAnchor == nil { onAnchor = asset }
            } else if day > targetDay {
                if firstAfter == nil { firstAfter = asset }
            } else {
                lastBefore = asset
            }
        }

        return onAnchor ?? firstAfter ?? lastBefore
    }
}
