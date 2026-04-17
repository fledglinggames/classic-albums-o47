import SwiftUI

struct MediaTypesSection: View {
    let items: [MediaTypeAlbum]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Media Types")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: AlbumsNavDestination.album(item.album)) {
                        MediaTypeRow(label: item.label, iconName: item.iconName, count: item.album.count)
                    }
                    .buttonStyle(.plain)
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    }
}

private struct MediaTypeRow: View {
    let label: String
    let iconName: String
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)

            Text(label)
                .font(.system(size: 17))
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
