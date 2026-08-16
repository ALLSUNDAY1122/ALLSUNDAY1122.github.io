struct ScanLabMapBounds: Equatable, Sendable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

enum ScanLabMapQueryPolicy {
    static func boundingBox(
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) -> ScanLabMapBounds? {
        let values = [centerLatitude, centerLongitude, latitudeDelta, longitudeDelta]
        guard values.allSatisfy(\.isFinite) else { return nil }
        guard (-90...90).contains(centerLatitude), (-180...180).contains(centerLongitude) else { return nil }

        let latSpan = abs(latitudeDelta)
        let lonSpan = abs(longitudeDelta)
        guard latSpan > 0, lonSpan > 0, latSpan <= 90, lonSpan <= 180 else { return nil }

        let minLat = centerLatitude - latSpan / 2
        let maxLat = centerLatitude + latSpan / 2
        let minLon = centerLongitude - lonSpan / 2
        let maxLon = centerLongitude + lonSpan / 2

        // The backend contract accepts one non-wrapping box. Returning nil tells the
        // caller to fall back to the global latest feed instead of issuing a partial box.
        guard minLat >= -90, maxLat <= 90, minLon >= -180, maxLon <= 180 else { return nil }

        return ScanLabMapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
}
