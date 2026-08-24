import Foundation

private struct AW34FixedWindowVirtualModel {
    let windowNanoseconds: UInt64
    private(set) var deadline: UInt64?
    private(set) var openedAt: UInt64?
    private(set) var latestTicket: UInt64?
    private(set) var executed: UInt64 = 0
    private(set) var superseded: UInt64 = 0
    private(set) var maximumOpenToDispatchNanoseconds: UInt64 = 0
    private(set) var lastExecutedTicket: UInt64?

    mutating func submit(ticket: UInt64, at now: UInt64) {
        drain(until: now)
        if latestTicket != nil { superseded += 1 }
        latestTicket = ticket
        if deadline == nil {
            openedAt = now
            deadline = now + windowNanoseconds
        }
    }

    mutating func drain(until now: UInt64) {
        guard let deadline,
              deadline <= now,
              let openedAt,
              let latestTicket else { return }
        executed += 1
        lastExecutedTicket = latestTicket
        maximumOpenToDispatchNanoseconds = max(
            maximumOpenToDispatchNanoseconds,
            deadline - openedAt
        )
        self.deadline = nil
        self.openedAt = nil
        self.latestTicket = nil
    }

    mutating func flush(at now: UInt64) {
        guard let openedAt, let latestTicket else { return }
        executed += 1
        lastExecutedTicket = latestTicket
        maximumOpenToDispatchNanoseconds = max(
            maximumOpenToDispatchNanoseconds,
            now - openedAt
        )
        deadline = nil
        self.openedAt = nil
        self.latestTicket = nil
    }

    mutating func supersedePending() {
        if latestTicket != nil { superseded += 1 }
        deadline = nil
        openedAt = nil
        latestTicket = nil
    }
}

private struct AW34ResettableDebounceVirtualModel {
    let windowNanoseconds: UInt64
    private(set) var deadline: UInt64?
    private(set) var latestTicket: UInt64?
    private(set) var executed: UInt64 = 0
    private(set) var superseded: UInt64 = 0

    mutating func submit(ticket: UInt64, at now: UInt64) {
        drain(until: now)
        if latestTicket != nil { superseded += 1 }
        latestTicket = ticket
        deadline = now + windowNanoseconds
    }

    mutating func drain(until now: UInt64) {
        guard let deadline, deadline <= now, latestTicket != nil else { return }
        executed += 1
        self.deadline = nil
        latestTicket = nil
    }
}

@main
struct L3AW34FixedWindowCoalescingStress {
    static func main() {
        let window: UInt64 = 16_000_000

        // 1kHz UI stream for one second: the historical resettable debounce does not become
        // eligible until the stream stops. Fixed-window coalescing continues producing winners.
        var fixed = AW34FixedWindowVirtualModel(windowNanoseconds: window)
        var old = AW34ResettableDebounceVirtualModel(windowNanoseconds: window)
        for index in 1...1_000 {
            let now = UInt64(index - 1) * 1_000_000
            fixed.submit(ticket: UInt64(index), at: now)
            old.submit(ticket: UInt64(index), at: now)
        }
        fixed.drain(until: 1_100_000_000)
        old.drain(until: 1_100_000_000)
        precondition(fixed.executed > 1)
        precondition(old.executed == 1)
        precondition(fixed.executed + fixed.superseded == 1_000)
        precondition(fixed.maximumOpenToDispatchNanoseconds <= window)

        // One million deterministic replacements at 8kHz. Every input must be accounted for as a
        // fixed-window winner or a pre-token supersession, and the first-intent eligibility bound
        // must never exceed the configured 16ms window.
        var stress = AW34FixedWindowVirtualModel(windowNanoseconds: window)
        let spacing: UInt64 = 125_000
        for index in 1...1_000_000 {
            stress.submit(
                ticket: UInt64(index),
                at: UInt64(index - 1) * spacing
            )
        }
        stress.drain(until: UInt64(1_000_000) * spacing + window)
        precondition(stress.executed > 1)
        precondition(stress.executed + stress.superseded == 1_000_000)
        precondition(stress.maximumOpenToDispatchNanoseconds == window)
        precondition(stress.lastExecutedTicket == 1_000_000)

        // Barrier semantics remain distinct from coalescing: play/pause-style flush executes the
        // latest pending value immediately, while a superseding lifecycle/media boundary consumes no
        // continuous token.
        var barrier = AW34FixedWindowVirtualModel(windowNanoseconds: window)
        barrier.submit(ticket: 1, at: 0)
        barrier.submit(ticket: 2, at: 2_000_000)
        barrier.flush(at: 3_000_000)
        precondition(barrier.executed == 1)
        precondition(barrier.lastExecutedTicket == 2)
        barrier.submit(ticket: 3, at: 4_000_000)
        barrier.supersedePending()
        precondition(barrier.executed == 1)
        precondition(barrier.superseded == 2)

        print(
            "L3-AW34 fixed-window virtual stress PASS "
            + "streamFixed=\(fixed.executed) oldDebounce=\(old.executed) "
            + "stressExecuted=\(stress.executed) stressSuperseded=\(stress.superseded) "
            + "maxWindowNs=\(stress.maximumOpenToDispatchNanoseconds)"
        )
    }
}
