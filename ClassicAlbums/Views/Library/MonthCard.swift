import SwiftUI
import Photos

struct MonthCard: View {
    let year: Int
    let month: Int
    let cover: PHAsset

    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(16)
            }
            .contentShape(Rectangle())
            .task(id: cover.localIdentifier) {
                let scale = UIScreen.main.scale
                let targetHeight = cardHeight * scale
                let targetWidth = UIScreen.main.bounds.width * scale
                image = await ThumbnailCache.shared.image(
                    for: cover,
                    size: CGSize(width: targetWidth, height: targetHeight)
                )
            }
    }

    private var title: String {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else {
            return "\(month) \(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var cardHeight: CGFloat {
        UIScreen.main.bounds.height * 0.32
    }
}
