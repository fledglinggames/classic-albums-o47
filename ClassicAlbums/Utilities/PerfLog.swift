import Foundation

@MainActor
enum PerfLog {
    private static var counters: [String: Int] = [:]
    private static var lastFlush: CFAbsoluteTime = 0

    static func hit(_ label: String) {
        counters[label, default: 0] += 1
        flushIfDue()
    }

    @discardableResult
    static func measure<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print(String(format: "[perf] %@: %.2fms", label, ms))
        return result
    }

    private static func flushIfDue() {
        let now = CFAbsoluteTimeGetCurrent()
        if lastFlush == 0 { lastFlush = now; return }
        guard now - lastFlush >= 0.5 else { return }
        lastFlush = now
        let pairs = counters.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        print("[perf] counters: \(pairs)")
        counters.removeAll()
    }
}
