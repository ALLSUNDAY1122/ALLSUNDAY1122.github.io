import Foundation

public struct Vector2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2()

    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

public struct AABB: Equatable, Sendable {
    public var center: Vector2
    public var halfSize: Vector2

    public init(center: Vector2, halfSize: Vector2) {
        self.center = center
        self.halfSize = halfSize
    }

    public var minX: Double { center.x - halfSize.x }
    public var maxX: Double { center.x + halfSize.x }
    public var minY: Double { center.y - halfSize.y }
    public var maxY: Double { center.y + halfSize.y }
}

@inline(__always)
func approach(_ value: Double, _ target: Double, by amount: Double) -> Double {
    if value < target { return min(value + amount, target) }
    if value > target { return max(value - amount, target) }
    return target
}
