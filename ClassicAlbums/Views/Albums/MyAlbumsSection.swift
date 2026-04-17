import SwiftUI

struct MyAlbumsSection: View {
    let albums: [Album]

    private var pages: [[Album]] {
        stride(from: 0, to: albums.count, by: 4).map { start in
            Array(albums[start..<min(start + 4, albums.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Albums")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                NavigationLink(value: AlbumsNavDestination.seeAll) {
                    Text("See All")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 16)

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 16
                let columnSpacing: CGFloat = 16
                let pageWidth = proxy.size.width
                let cellSize = (pageWidth - horizontalPadding * 2 - columnSpacing) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(pages.indices, id: \.self) { pageIdx in
                            pageContent(pages[pageIdx], cellSize: cellSize)
                                .frame(width: pageWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
            }
            .frame(height: cellHeight(forWidth: effectiveWidth))
        }
    }

    private var effectiveWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    private func cellHeight(forWidth width: CGFloat) -> CGFloat {
        let cellSize = (width - 16 * 2 - 16) / 2
        return cellSize * 2 + 16 + 88
    }

    @ViewBuilder
    private func pageContent(_ pageAlbums: [Album], cellSize: CGFloat) -> some View {
        HStack(spacing: 16) {
            ForEach(0..<2, id: \.self) { col in
                VStack(spacing: 16) {
                    ForEach(0..<2, id: \.self) { row in
                        let idx = col * 2 + row
                        if idx < pageAlbums.count {
                            NavigationLink(value: AlbumsNavDestination.album(pageAlbums[idx])) {
                                AlbumCell(album: pageAlbums[idx], thumbnailSize: cellSize)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize + 44)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}
