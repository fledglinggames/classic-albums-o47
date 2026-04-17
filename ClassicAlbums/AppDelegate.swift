import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var allowedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.allowedOrientations
    }
}
