import Foundation

/// FIFO async mutex for Library operations whose correctness depends on one coherent artifact-
/// reference snapshot across multiple awaited metadata/filesystem steps. The actor only manages
/// admission; the protected operation executes outside actor isolation so Swift actor reentrancy
/// cannot admit a second mutation until `unlock()` explicitly hands ownership to the next waiter.
public actor Lane2LibraryMutationGate {
    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func lock() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func unlock() {
        precondition(locked, "Lane2LibraryMutationGate unlock without ownership")
        guard !waiters.isEmpty else {
            locked = false
            return
        }
        let next = waiters.removeFirst()
        next.resume()
    }
}
