import SwiftUI

struct SettingsView: View {
    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @State private var showingResetConfirm = false
    @AppStorage("pixelArtCrispThreshold") private var pixelArtCrispThreshold: Int = 256

    var body: some View {
        NavigationStack {
            List {
                Section("Pixel Art: Crisp View") {
                    Picker("Threshold", selection: $pixelArtCrispThreshold) {
                        Text("512×512 or smaller").tag(512)
                        Text("256×256 or smaller").tag(256)
                        Text("128×128 or smaller").tag(128)
                        Text("Off").tag(0)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        showingResetConfirm = true
                    } label: {
                        Text("Reset album order to match iOS Photos app")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("This replaces your custom album order in Classic Albums with the current order from the iOS Photos app.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset album order?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Album Order", role: .destructive) {
                    photoLibrary.resetAlbumOrderToSystem()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your custom album order will be replaced with the order from the iOS Photos app.")
            }
        }
    }
}
