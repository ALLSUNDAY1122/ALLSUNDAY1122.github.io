import Foundation

public struct ObserverLocation: Sendable, Equatable {
    public let latitudeDegrees: Double
    public let longitudeDegrees: Double

    public init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.latitudeDegrees = latitudeDegrees
        self.longitudeDegrees = longitudeDegrees
    }
}

public struct EquatorialCoordinate: Sendable, Equatable {
    public let rightAscensionHours: Double
    public let declinationDegrees: Double

    public init(rightAscensionHours: Double, declinationDegrees: Double) {
        self.rightAscensionHours = rightAscensionHours
        self.declinationDegrees = declinationDegrees
    }
}

public struct HorizontalCoordinate: Sendable, Equatable {
    /// 0° = North, 90° = East.
    public let azimuthDegrees: Double
    /// 0° = horizon, 90° = zenith.
    public let altitudeDegrees: Double
}

public enum SpatialDirectionCore {
    public static func horizontalCoordinate(
        equatorial: EquatorialCoordinate,
        observer: ObserverLocation,
        date: Date
    ) -> HorizontalCoordinate {
        let jd = julianDate(date)
        let t = (jd - 2_451_545.0) / 36_525.0
        let gmst = normalizedDegrees(
            280.46061837
            + 360.98564736629 * (jd - 2_451_545.0)
            + 0.000387933 * t * t
            - (t * t * t) / 38_710_000.0
        )

        let localSiderealDegrees = normalizedDegrees(gmst + observer.longitudeDegrees)
        let hourAngleDegrees = normalizedSignedDegrees(
            localSiderealDegrees - equatorial.rightAscensionHours * 15.0
        )

        let latitude = radians(observer.latitudeDegrees)
        let declination = radians(equatorial.declinationDegrees)
        let hourAngle = radians(hourAngleDegrees)

        let sinAltitude =
            sin(declination) * sin(latitude)
            + cos(declination) * cos(latitude) * cos(hourAngle)
        let altitude = asin(clamp(sinAltitude, -1.0, 1.0))

        // Astronomical azimuth, normalized so 0° is north and 90° is east.
        let azimuth = atan2(
            sin(hourAngle),
            cos(hourAngle) * sin(latitude) - tan(declination) * cos(latitude)
        ) + .pi

        return HorizontalCoordinate(
            azimuthDegrees: normalizedDegrees(degrees(azimuth)),
            altitudeDegrees: degrees(altitude)
        )
    }

    public static func julianDate(_ date: Date) -> Double {
        // Unix epoch 1970-01-01T00:00:00Z = JD 2440587.5
        date.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private static func degrees(_ radians: Double) -> Double { radians * 180.0 / .pi }

    private static func normalizedDegrees(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360.0)
        return remainder >= 0 ? remainder : remainder + 360.0
    }

    private static func normalizedSignedDegrees(_ value: Double) -> Double {
        let normalized = normalizedDegrees(value)
        return normalized > 180.0 ? normalized - 360.0 : normalized
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
