import SwiftUI
import UIKit
import Photos

struct PhotoViewerPagedView: UIViewControllerRepresentable {
    let assets: [PHAsset]
    @Binding var selectedIndex: Int
    @Binding var zoomScale: CGFloat
    var onSingleTap: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 16]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .systemBackground
        context.coordinator.parent = self

        if assets.indices.contains(selectedIndex) {
            let initial = context.coordinator.makePage(
                asset: assets[selectedIndex],
                index: selectedIndex
            )
            pvc.setViewControllers([initial], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        guard assets.indices.contains(selectedIndex) else { return }
        let current = pvc.viewControllers?.first as? PhotoPageViewController

        if let current, current.index == selectedIndex {
            return
        }

        let direction: UIPageViewController.NavigationDirection
        if let current {
            direction = selectedIndex > current.index ? .forward : .reverse
        } else {
            direction = .forward
        }
        let next = context.coordinator.makePage(
            asset: assets[selectedIndex],
            index: selectedIndex
        )
        pvc.setViewControllers([next], direction: direction, animated: false)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PhotoViewerPagedView?

        func makePage(asset: PHAsset, index: Int) -> PhotoPageViewController {
            guard let parent else {
                fatalError("PhotoViewerPagedView.Coordinator.parent unset")
            }
            return PhotoPageViewController(
                asset: asset,
                index: index,
                zoomScale: parent.$zoomScale,
                onSingleTap: parent.onSingleTap
            )
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerBefore vc: UIViewController
        ) -> UIViewController? {
            guard let parent,
                  let page = vc as? PhotoPageViewController,
                  page.index > 0,
                  parent.assets.indices.contains(page.index - 1) else { return nil }
            return makePage(asset: parent.assets[page.index - 1], index: page.index - 1)
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerAfter vc: UIViewController
        ) -> UIViewController? {
            guard let parent,
                  let page = vc as? PhotoPageViewController,
                  parent.assets.indices.contains(page.index + 1) else { return nil }
            return makePage(asset: parent.assets[page.index + 1], index: page.index + 1)
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let current = pvc.viewControllers?.first as? PhotoPageViewController,
                  let parent else { return }
            DispatchQueue.main.async {
                parent.selectedIndex = current.index
            }
        }
    }
}

final class PhotoPageViewController: UIViewController {
    let index: Int
    let asset: PHAsset
    private let zoomScale: Binding<CGFloat>
    private let onSingleTap: () -> Void

    private var hostingController: UIHostingController<PhotoPageContent>?
    private var isActive: Bool = false

    init(asset: PHAsset, index: Int, zoomScale: Binding<CGFloat>, onSingleTap: @escaping () -> Void) {
        self.asset = asset
        self.index = index
        self.zoomScale = zoomScale
        self.onSingleTap = onSingleTap
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let hc = UIHostingController(rootView: makeContent())
        hc.view.backgroundColor = .clear
        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hc.didMove(toParent: self)
        self.hostingController = hc
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setActive(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setActive(false)
    }

    private func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        hostingController?.rootView = makeContent()
    }

    private func makeContent() -> PhotoPageContent {
        PhotoPageContent(
            asset: asset,
            isActive: isActive,
            zoomScale: zoomScale,
            onSingleTap: onSingleTap
        )
    }
}
