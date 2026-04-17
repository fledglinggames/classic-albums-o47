import SwiftUI
import UIKit

struct FullAccessRequiredView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                Text("Full Access Required")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)

                Text("Classic Albums needs full access to your photo library to display and organize your photos.")
                    .font(.body)

                Button(action: openSettings) {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.vertical, 4)

                NoteAboutMakingOwnApp()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
