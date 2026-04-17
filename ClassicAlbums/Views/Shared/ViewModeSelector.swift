import SwiftUI

struct ViewModeSelector: View {
    @Binding var selection: LibraryViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: selection == mode ? .semibold : .regular))
                        .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if selection == mode {
                                Capsule().fill(Color(.tertiarySystemBackground))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .padding(.bottom, 8)
    }
}
