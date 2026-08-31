import Foundation

public protocol CollisionWorld: Sendable {
    var solidBounds: [AABB] { get }
}

public struct StaticCollisionWorld: CollisionWorld, Sendable {
    public var solidBounds: [AABB]

    public init(solidBounds: [AABB]) {
        self.solidBounds = solidBounds
    }
}

public struct CollisionContacts: Equatable, Sendable {
    public var floor = false
    public var ceiling = false
    public var wallLeft = false
    public var wallRight = false

    public init() {}

    mutating func formUnion(_ other: CollisionContacts) {
        floor = floor || other.floor
        ceiling = ceiling || other.ceiling
        wallLeft = wallLeft || other.wallLeft
        wallRight = wallRight || other.wallRight
    }
}

public enum AxisSeparatedCollisionSolver {
    /// Swept-by-substeps AABB solver. The crossing tests inside each micro-step prevent
    /// tunneling, while the bounded travel per substep prevents diagonal corner skips.
    public static func move(
        position: Vector2,
        velocity: Vector2,
        halfSize: Vector2,
        dt: Double,
        world: any CollisionWorld
    ) -> (position: Vector2, velocity: Vector2, contacts: CollisionContacts) {
        guard dt > 0 else {
            return (position, velocity, probeContacts(position: position, halfSize: halfSize, world: world))
        }

        var p = resolveInitialPenetration(position: position, halfSize: halfSize, world: world)
        var v = velocity
        var contacts = CollisionContacts()

        let totalDx = abs(v.x * dt)
        let totalDy = abs(v.y * dt)
        let bodyScale = max(0.02, min(halfSize.x, halfSize.y))
        let maxTravel = max(0.02, bodyScale * 0.40)
        let count = max(1, min(256, Int(ceil(max(totalDx, totalDy) / maxTravel))))
        let subDt = dt / Double(count)

        for _ in 0..<count {
            let solved = moveSingle(position: p, velocity: v, halfSize: halfSize, dt: subDt, world: world)
            p = solved.position
            v = solved.velocity
            contacts.formUnion(solved.contacts)
        }

        contacts.formUnion(probeContacts(position: p, halfSize: halfSize, world: world))
        return (p, v, contacts)
    }

    private static func moveSingle(
        position: Vector2,
        velocity: Vector2,
        halfSize: Vector2,
        dt: Double,
        world: any CollisionWorld
    ) -> (position: Vector2, velocity: Vector2, contacts: CollisionContacts) {
        var p = position
        var v = velocity
        var contacts = CollisionContacts()

        let dx = v.x * dt
        if dx != 0 {
            let oldMinX = p.x - halfSize.x
            let oldMaxX = p.x + halfSize.x
            let newMinX = oldMinX + dx
            let newMaxX = oldMaxX + dx
            let minY = p.y - halfSize.y
            let maxY = p.y + halfSize.y

            var resolvedX = p.x + dx
            if dx > 0 {
                var nearest = Double.infinity
                for solid in world.solidBounds where intervalsOverlap(minY, maxY, solid.minY, solid.maxY) {
                    if oldMaxX <= solid.minX && newMaxX >= solid.minX && solid.minX < nearest {
                        nearest = solid.minX
                    }
                }
                if nearest.isFinite {
                    resolvedX = nearest - halfSize.x
                    v.x = 0
                    contacts.wallRight = true
                }
            } else {
                var nearest = -Double.infinity
                for solid in world.solidBounds where intervalsOverlap(minY, maxY, solid.minY, solid.maxY) {
                    if oldMinX >= solid.maxX && newMinX <= solid.maxX && solid.maxX > nearest {
                        nearest = solid.maxX
                    }
                }
                if nearest.isFinite {
                    resolvedX = nearest + halfSize.x
                    v.x = 0
                    contacts.wallLeft = true
                }
            }
            p.x = resolvedX
        }

        let dy = v.y * dt
        if dy != 0 {
            let oldMinY = p.y - halfSize.y
            let oldMaxY = p.y + halfSize.y
            let newMinY = oldMinY + dy
            let newMaxY = oldMaxY + dy
            let minX = p.x - halfSize.x
            let maxX = p.x + halfSize.x

            var resolvedY = p.y + dy
            if dy > 0 {
                var nearest = Double.infinity
                for solid in world.solidBounds where intervalsOverlap(minX, maxX, solid.minX, solid.maxX) {
                    if oldMaxY <= solid.minY && newMaxY >= solid.minY && solid.minY < nearest {
                        nearest = solid.minY
                    }
                }
                if nearest.isFinite {
                    resolvedY = nearest - halfSize.y
                    v.y = 0
                    contacts.ceiling = true
                }
            } else {
                var nearest = -Double.infinity
                for solid in world.solidBounds where intervalsOverlap(minX, maxX, solid.minX, solid.maxX) {
                    if oldMinY >= solid.maxY && newMinY <= solid.maxY && solid.maxY > nearest {
                        nearest = solid.maxY
                    }
                }
                if nearest.isFinite {
                    resolvedY = nearest + halfSize.y
                    v.y = 0
                    contacts.floor = true
                }
            }
            p.y = resolvedY
        }

        return (p, v, contacts)
    }

    /// Keeps floor/wall/ceiling contacts stable even when the relevant velocity axis is zero.
    private static func probeContacts(
        position: Vector2,
        halfSize: Vector2,
        world: any CollisionWorld
    ) -> CollisionContacts {
        var contacts = CollisionContacts()
        let eps = 0.000_01
        let minX = position.x - halfSize.x
        let maxX = position.x + halfSize.x
        let minY = position.y - halfSize.y
        let maxY = position.y + halfSize.y

        for solid in world.solidBounds {
            if intervalsOverlap(minX, maxX, solid.minX, solid.maxX) {
                if abs(minY - solid.maxY) <= eps { contacts.floor = true }
                if abs(maxY - solid.minY) <= eps { contacts.ceiling = true }
            }
            if intervalsOverlap(minY, maxY, solid.minY, solid.maxY) {
                if abs(minX - solid.maxX) <= eps { contacts.wallLeft = true }
                if abs(maxX - solid.minX) <= eps { contacts.wallRight = true }
            }
        }
        return contacts
    }

    /// Defensive recovery for spawn/teleport rounding or prior-frame corner penetration.
    /// Chooses the smallest separating translation and repeats a few times for stacked solids.
    private static func resolveInitialPenetration(
        position: Vector2,
        halfSize: Vector2,
        world: any CollisionWorld
    ) -> Vector2 {
        var p = position
        for _ in 0..<4 {
            var bestDelta: Vector2?
            var bestMagnitude = Double.infinity
            let minX = p.x - halfSize.x
            let maxX = p.x + halfSize.x
            let minY = p.y - halfSize.y
            let maxY = p.y + halfSize.y

            for solid in world.solidBounds where intervalsOverlap(minX, maxX, solid.minX, solid.maxX) && intervalsOverlap(minY, maxY, solid.minY, solid.maxY) {
                let candidates = [
                    Vector2(x: solid.minX - maxX, y: 0),
                    Vector2(x: solid.maxX - minX, y: 0),
                    Vector2(x: 0, y: solid.minY - maxY),
                    Vector2(x: 0, y: solid.maxY - minY)
                ]
                for delta in candidates {
                    let mag = abs(delta.x) + abs(delta.y)
                    if mag < bestMagnitude {
                        bestMagnitude = mag
                        bestDelta = delta
                    }
                }
            }

            guard let delta = bestDelta else { break }
            p = p + delta
        }
        return p
    }

    @inline(__always)
    private static func intervalsOverlap(_ aMin: Double, _ aMax: Double, _ bMin: Double, _ bMax: Double) -> Bool {
        aMax > bMin && aMin < bMax
    }
}
