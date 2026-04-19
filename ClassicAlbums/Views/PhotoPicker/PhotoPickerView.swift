import SwiftUI
import Photos

struct PhotoPickerView: View {
    let targetAlbum: Album
    var onDone: () -> Void

    @Environment(PhotoLibraryManager.self) private var photoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var assets: PHFetchResult<PHAsset>?
    @State private var selected: Set<String> = []
    @State private var isSaving = false

    private let spacing: CGFloat = 2
    private let columns = 3

    var body: some View {
        NavigationStack {
            Group {
                if let assets, assets.count > 0 {
                    grid(assets: assets)
                } else if assets != nil {
                    Text("No Photos")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Add to \(targetAlbum.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(addLabel) { add() }
                        .disabled(selected.isEmpty || isSaving)
                }
            }
            .task {
                if assets == nil {
                    assets = loadRecents()
                }
            }
        }
    }

    private var addLabel: String {
        selected.isEmpty ? "Add" : "Add (\(selected.count))"
    }

    private func grid(assets: PHFetchResult<PHAsset>) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cellSize = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)

            ScrollView {
                LazyVGrid(columns: gridItems, spacing: spacing) {
                    ForEach(0..<assets.count, id: \.self) { idx in
                        let asset = assets.object(at: idx)
                        Button {
                            toggle(asset)
                        } label: {
                            PickerCell(asset: asset, size: cellSize)
                                .overlay(alignment: .bottomTrailing) {
                                    selectionBadge(selected: selected.contains(asset.localIdentifier))
                                        .padding(6)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func selectionBadge(selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? Color.accentColor : Color.black.opacity(0.35))
                .frame(width: 24, height: 24)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 24, height: 24)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func toggle(_ asset: PHAsset) {
        if selected.contains(asset.localIdentifier) {
            selected.remove(asset.localIdentifier)
        } else {
            selected.insert(asset.localIdentifier)
        }
    }

    private func loadRecents() -> PHFetchResult<PHAsset>? {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil
        )
        guard let collection = result.firstObject else { return nil }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(in: collection, options: options)
    }

    private struct PickerCell: View {
        let asset: PHAsset
        let size: CGFloat
        @State private var image: UIImage?

        var body: some View {
            PhotoGridCellView(asset: asset, image: image, size: size)
                .task(id: asset.localIdentifier) {
                    let scale = UIScreen.main.scale
                    let target = CGSize(width: size * scale, height: size * scale)
                    for await img in ImageService.shared.requestThumbnail(for: asset, targetSize: target) {
                        if Task.isCancelled { return }
                        image = img
                    }
                }
        }
    }

    private func add() {
        guard let assets, !selected.isEmpty else { return }
        isSaving = true
        var pickedAssets: [PHAsset] = []
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            if selected.contains(asset.localIdentifier) {
                pickedAssets.append(asset)
            }
        }
        let target = targetAlbum
        Task {
            do {
                try await photoLibrary.addAssets(pickedAssets, to: target)
                onDone()
                dismiss()
            } catch {
                print("Error adding to album: \(error)")
                isSaving = false
            }
        }
    }
}
