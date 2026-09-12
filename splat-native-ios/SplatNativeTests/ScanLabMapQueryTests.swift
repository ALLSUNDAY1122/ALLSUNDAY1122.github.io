import MapKit
import Testing

struct ScanLabMapQueryTests {
    @Test func boundsClampToWorldLimits() {
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 89, longitude: 179), span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20))
        let bounds = ScanLabMapBounds.make(from: region)
        #expect(bounds.minLat == 79)
        #expect(bounds.maxLat == 90)
        #expect(bounds.minLon == 169)
        #expect(bounds.maxLon == 180)
    }

    @Test func validCoordinateRejectsNonFiniteAndOutOfRangeValues() {
        #expect(ScanLabMapQueryPolicy.isValid(latitude: 35.6812, longitude: 139.7671))
        #expect(!ScanLabMapQueryPolicy.isValid(latitude: 91, longitude: 139))
        #expect(!ScanLabMapQueryPolicy.isValid(latitude: 35, longitude: 181))
        #expect(!ScanLabMapQueryPolicy.isValid(latitude: .nan, longitude: 139))
        #expect(!ScanLabMapQueryPolicy.isValid(latitude: 35, longitude: .infinity))
    }
}
