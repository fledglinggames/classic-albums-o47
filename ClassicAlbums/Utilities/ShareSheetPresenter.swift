import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any], activities: [UIActivity] = []) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController
        else { return }

        var presenter: UIViewController = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: activities)
        vc.popoverPresentationController?.sourceView = presenter.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.maxY,
            width: 0, height: 0
        )
        presenter.present(vc, animated: true)
    }
}
