import Foundation

// Serialize Mesh writer admission with reset to prevent stale queued JPEG writes.
final class MeshFrameWriteFence: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = UUID()

    func rotate() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        return generation
    }

    func performIfCurrent(_ expected: UUID, _ body: () -> Bool) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expected else { return nil }
        return body()
    }
}
