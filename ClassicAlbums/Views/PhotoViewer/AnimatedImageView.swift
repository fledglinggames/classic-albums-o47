import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage
    var crisp: Bool = false

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        iv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iv.setContentHuggingPriority(.defaultLow, for: .vertical)
        iv.image = image
        iv.startAnimating()
        applyFilters(to: iv)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image !== image {
            uiView.image = image
            uiView.startAnimating()
        }
        applyFilters(to: uiView)
    }

    private func applyFilters(to iv: UIImageView) {
        let filter: CALayerContentsFilter = crisp ? .nearest : .linear
        iv.layer.magnificationFilter = filter
        iv.layer.minificationFilter = filter
    }
}

enum GIFDecoder {
    static func decode(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            totalDuration += frameDelay(source: source, index: i)
        }

        guard !frames.isEmpty else { return nil }
        if totalDuration <= 0 { totalDuration = Double(frames.count) / 10.0 }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let delay = gif[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }
}
