import SwiftUI
import UIKit

@MainActor
enum SheetPresenter {
    static func present<Content: View>(
        detents: [UISheetPresentationController.Detent] = [.large()],
        @ViewBuilder content: () -> Content
    ) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController
        else { return }

        var presenter: UIViewController = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let host = UIHostingController(rootView: content())
        host.modalPresentationStyle = .formSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = detents
        }
        presenter.present(host, animated: true)
    }
}
