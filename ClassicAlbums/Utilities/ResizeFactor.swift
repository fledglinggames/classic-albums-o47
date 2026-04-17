import Foundation

enum ResizeFactor: String, CaseIterable, Identifiable, Sendable {
    case half
    case threeQuarters
    case double
    case triple

    var id: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .half: return 0.5
        case .threeQuarters: return 0.75
        case .double: return 2.0
        case .triple: return 3.0
        }
    }

    var label: String {
        switch self {
        case .half: return "0.5×"
        case .threeQuarters: return "0.75×"
        case .double: return "2×"
        case .triple: return "3×"
        }
    }

    var isUpscale: Bool { multiplier > 1.0 }
}
