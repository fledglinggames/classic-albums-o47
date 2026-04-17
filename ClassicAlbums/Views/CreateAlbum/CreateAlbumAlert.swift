import SwiftUI

struct CreateAlbumAlertModifier: ViewModifier {
    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @Binding var isPresented: Bool
    @State private var albumName: String = ""

    func body(content: Content) -> some View {
        content.alert("New Album", isPresented: $isPresented) {
            TextField("Title", text: $albumName)
            Button("Cancel", role: .cancel) {
                albumName = ""
            }
            Button("Save") {
                createAlbum()
            }
            .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for this album.")
        }
    }

    private func createAlbum() {
        let name = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        albumName = ""
        Task {
            do {
                try await photoLibrary.createAlbum(named: name)
            } catch {
                print("Error creating album: \(error)")
            }
        }
    }
}

extension View {
    func createAlbumAlert(isPresented: Binding<Bool>) -> some View {
        modifier(CreateAlbumAlertModifier(isPresented: isPresented))
    }
}
