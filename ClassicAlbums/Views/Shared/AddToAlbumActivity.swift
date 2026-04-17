import UIKit
import Photos

final class AddToAlbumActivity: UIActivity {
    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init()
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.classicalbums.addToAlbum")
    }

    override var activityTitle: String? { "Add to Album" }

    override var activityImage: UIImage? {
        UIImage(systemName: "rectangle.stack.badge.plus")
    }

    override class var activityCategory: UIActivity.Category { .action }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func perform() {
        onTap()
        activityDidFinish(true)
    }
}
