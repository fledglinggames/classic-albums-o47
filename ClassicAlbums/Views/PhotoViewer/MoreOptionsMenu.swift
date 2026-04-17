import SwiftUI
import Photos

struct MoreOptionsMenu: View {
    var onCopy: () -> Void
    var onDuplicate: () -> Void
    var onDuplicateWithResize: () -> Void
    var onHide: () -> Void
    var onAdjustDate: () -> Void

    var body: some View {
        Menu {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button {
                onDuplicateWithResize()
            } label: {
                Label("Duplicate With Resize", systemImage: "square.resize")
            }
            Button {
                onHide()
            } label: {
                Label("Hide", systemImage: "eye.slash")
            }
            Button {
                onAdjustDate()
            } label: {
                Label("Adjust Date & Time", systemImage: "calendar")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
