import SwiftUI
import Photos

struct ContentView: View {
    @AppStorage("hasSeenPermissionNote") private var hasSeenPermissionNote = false
    @State private var photoLibrary = PhotoLibraryManager()
    @State private var selectedTab: Int = 1
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if photoLibrary.authorizationStatus == .notDetermined && !hasSeenPermissionNote {
                PermissionNoteView {
                    hasSeenPermissionNote = true
                    Task {
                        await photoLibrary.requestAuthorization()
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    LibraryView()
                        .tabItem {
                            Label("Library", systemImage: "photo.on.rectangle")
                        }
                        .tag(0)

                    AlbumsView()
                        .tabItem {
                            Label("Albums", systemImage: "rectangle.stack")
                        }
                        .tag(1)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(2)
                }
                .task(id: photoLibrary.authorizationStatus) {
                    if photoLibrary.authorizationStatus == .notDetermined {
                        await photoLibrary.requestAuthorization()
                    }
                }
            }
        }
        .environment(photoLibrary)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                photoLibrary.refreshAuthorizationStatus()
            }
        }
    }
}

#Preview {
    ContentView()
}
