# Progression Test Plan

Session B acceptance suite will be implemented under this directory over `next1` through `next5`.

Required coverage:

1. Stage lifecycle: Start -> checkpoints -> Goal, retry, timer, best-time persistence, duplicate completion protection.
2. Availability: mandatory stage unlock chain cannot deadlock; locked reasons are UI-queryable.
3. Economy: add/spend atomicity, large-number normalization, passive rate aggregation, clone reward monotonicity.
4. Upgrades: cost curves are monotonic, max-level handling is deterministic, effects are queryable before purchase.
5. Ability progression: each mandatory ability has a reachable purchase/unlock path and at least one forward + backward world use.
6. Balance simulation: no mandatory wait exceeds configured failure threshold under target play, prior stages retain non-zero economic relevance, secrets accelerate but are not required.
7. Signals: exactly-once unlock/completion semantics where required; economy events match mutations.
8. Integration: Session A gameplay callback stubs can drive Session B without importing Player/Physics/Replay internals.

Evidence per `next` must record tests run, failures found, fixes applied, balance deltas and the final commit SHA.
