import Foundation

@main
struct L3AW32BoundaryEnvelopeGenerationFenceSelfTest {
    static func main() throws {
        var fence = PlaybackBoundaryEnvelopeGenerationFence()
        let firstGeneration = try fence.invalidate()
        precondition(firstGeneration == 1)
        let first = fence.armRestartFadeIn()
        precondition(first == 1)
        precondition(fence.pendingRestartFadeInGeneration == 1)

        let secondGeneration = try fence.invalidate()
        precondition(secondGeneration == 2)
        precondition(fence.pendingRestartFadeInGeneration == nil)
        precondition(!fence.consumeRestartFadeIn(expectedGeneration: first))

        let second = fence.armRestartFadeIn()
        precondition(second == 2)
        precondition(fence.consumeRestartFadeIn(expectedGeneration: second))
        precondition(!fence.consumeRestartFadeIn(expectedGeneration: second))

        var overflow = PlaybackBoundaryEnvelopeGenerationFence(generation: UInt64.max)
        do {
            _ = try overflow.invalidate()
            preconditionFailure("generation overflow accepted")
        } catch PlaybackBoundaryEnvelopeError.generationOverflow { }
        precondition(overflow.overflowed)
        precondition(overflow.pendingRestartFadeInGeneration == nil)

        var stress = PlaybackBoundaryEnvelopeGenerationFence()
        var rejected = 0
        var consumed = 0
        for _ in 0..<500_000 {
            _ = try stress.invalidate()
            let stale = stress.armRestartFadeIn()
            _ = try stress.invalidate()
            if !stress.consumeRestartFadeIn(expectedGeneration: stale) { rejected += 1 }
            let current = stress.armRestartFadeIn()
            if stress.consumeRestartFadeIn(expectedGeneration: current) { consumed += 1 }
        }
        precondition(rejected == 500_000)
        precondition(consumed == 500_000)
        print(
            "L3-AW32 fence PASS staleRejected=\(rejected) currentConsumed=\(consumed) "
                + "finalGeneration=\(stress.generation)"
        )
    }
}
