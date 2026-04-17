import SwiftUI
import Photos

struct YearsView: View {
    let index: LibraryIndex

    private var years: [Int] { index.years }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(years, id: \.self) { year in
                        if let cover = CoverPhotoSelector.yearCover(
                            year: year,
                            assets: index.yearAssets[year] ?? [],
                            today: Date()
                        ) {
                            NavigationLink(value: LibraryNavDestination.monthsInYear(year)) {
                                YearCard(year: year, cover: cover)
                            }
                            .buttonStyle(.plain)
                            .id(year)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                if let last = years.last {
                    DispatchQueue.main.async {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
}
