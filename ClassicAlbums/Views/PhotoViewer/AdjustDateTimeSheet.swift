import SwiftUI

struct AdjustDateTimeSheet: View {
    let originalDate: Date
    var onAdjust: (Date) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(originalDate: Date, onAdjust: @escaping (Date) -> Void) {
        self.originalDate = originalDate
        self.onAdjust = onAdjust
        _date = State(initialValue: originalDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: [.date]
                )
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                DatePicker(
                    "Time",
                    selection: $date,
                    displayedComponents: [.hourAndMinute]
                )
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("Adjust Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adjust") {
                        onAdjust(date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}
