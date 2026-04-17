import SwiftUI
import UIKit

struct UtilitiesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Utilities")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Button(action: openPhotosApp) {
                    UtilityRow(label: "Hidden (external)", iconName: "eye.slash")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button(action: openPhotosApp) {
                    UtilityRow(label: "Recently Deleted (external)", iconName: "trash")
                }
                .buttonStyle(.plain)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    }

    private func openPhotosApp() {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }
}

private struct UtilityRow: View {
    let label: String
    let iconName: String

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

            Image(systemName: "lock.fill")
                .font(.system(size: 14))
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
