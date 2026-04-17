import SwiftUI
import Photos

struct MonthsView: View {
    let index: LibraryIndex
    var filterYear: Int? = nil

    private var months: [LibraryIndex.MonthKey] {
        index.months(inYear: filterYear)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(months, id: \.self) { key in
                        if let assets = index.monthAssets[key],
                           let cover = CoverPhotoSelector.monthCover(assets: assets, today: Date()) {
                            NavigationLink(value: LibraryNavDestination.allPhotosAtMonth(year: key.year, month: key.month)) {
                                MonthCard(year: key.year, month: key.month, cover: cover)
                            }
                            .buttonStyle(.plain)
                            .id(key)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                if let last = months.last {
                    DispatchQueue.main.async {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
}
