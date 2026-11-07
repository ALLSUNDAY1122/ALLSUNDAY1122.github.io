import Foundation
import MapKit

struct ScanLabMapBounds: Equatable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    static func make(from region: MKCoordinateRegion) -> ScanLabMapBounds {
        let halfLat = min(abs(region.span.latitudeDelta) / 2, 90)
        let halfLon = min(abs(region.span.longitudeDelta) / 2, 180)
        return ScanLabMapBounds(
            minLat: max(-90, region.center.latitude - halfLat),
            maxLat: min(90, region.center.latitude + halfLat),
            minLon: max(-180, region.center.longitude - halfLon),
            maxLon: min(180, region.center.longitude + halfLon)
        )
    }

    var backendTuple: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        (minLat, maxLat, minLon, maxLon)
    }
}

enum ScanLabMapQueryPolicy {
    static func isValid(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
