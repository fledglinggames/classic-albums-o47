import SwiftUI
import Photos

struct LibrarySelectionActiveKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct LibraryView: View {
    @Environment(PhotoLibraryManager.self) private var photoLibrary

    @State private var allPhotos: PHFetchResult<PHAsset>?
    @State private var index: LibraryIndex?
    @State private var viewMode: LibraryViewMode = LibraryViewModeStorage.load()
    @State private var path: [LibraryNavDestination] = []
    @State private var selectionActive: Bool = false

    var body: some View {
        switch photoLibrary.authorizationStatus {
        case .authorized:
            authorizedBody
        case .limited, .denied, .restricted, .notDetermined:
            FullAccessRequiredView()
        @unknown default:
            FullAccessRequiredView()
        }
    }

    private var authorizedBody: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                Group {
                    if let allPhotos, let index, allPhotos.count > 0 {
                        rootView(allPhotos: allPhotos, index: index)
                    } else if allPhotos != nil {
                        emptyState
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: LibraryNavDestination.self) { dest in
                    switch dest {
                    case .monthsInYear(let year):
                        if let index {
                            MonthsView(index: index, filterYear: year)
                        }
                    case .allPhotosAtMonth(let y, let m):
                        if let allPhotos {
                            AllPhotosView(allPhotos: allPhotos, scrollToMonth: (y, m))
                        }
                    }
                }
                .task {
                    if allPhotos == nil {
                        refreshLibrary()
                    }
                }
                .onChange(of: photoLibrary.libraryChangeCount) { _, _ in
                    refreshLibrary()
                }
                .onChange(of: viewMode) { _, newValue in
                    LibraryViewModeStorage.save(newValue)
                }
            }

            if !selectionActive {
                ViewModeSelector(selection: pillBinding)
            }
        }
        .onPreferenceChange(LibrarySelectionActiveKey.self) { selectionActive = $0 }
    }

    private var effectiveMode: LibraryViewMode {
        if let last = path.last {
            switch last {
            case .monthsInYear: return .months
            case .allPhotosAtMonth: return .allPhotos
            }
        }
        return viewMode
    }

    private var pillBinding: Binding<LibraryViewMode> {
        Binding(
            get: { effectiveMode },
            set: { newValue in
                guard newValue != effectiveMode else { return }
                path = []
                viewMode = newValue
            }
        )
    }

    private func refreshLibrary() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetched = PHAsset.fetchAssets(with: options)
        allPhotos = fetched
        index = LibraryIndex.build(from: fetched)
    }

    @ViewBuilder
    private func rootView(allPhotos: PHFetchResult<PHAsset>, index: LibraryIndex) -> some View {
        switch viewMode {
        case .years:
            YearsView(index: index)
        case .months:
            MonthsView(index: index, filterYear: nil)
        case .allPhotos:
            AllPhotosView(allPhotos: allPhotos)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Photos")
                .font(.system(size: 28, weight: .bold))
            Text("Your photo library is empty.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
