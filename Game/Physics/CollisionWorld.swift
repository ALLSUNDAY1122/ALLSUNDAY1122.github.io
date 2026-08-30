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
}

public enum AxisSeparatedCollisionSolver {
    public static func move(
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

    @inline(__always)
    private static func intervalsOverlap(_ aMin: Double, _ aMax: Double, _ bMin: Double, _ bMax: Double) -> Bool {
        aMax > bMin && aMin < bMax
    }
}
