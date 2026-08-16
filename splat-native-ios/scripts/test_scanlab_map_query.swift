@main
struct ScanLabMapQueryContractTest {
    static func main() {
        let tokyo = ScanLabMapQueryPolicy.boundingBox(
            centerLatitude: 35.68,
            centerLongitude: 139.70,
            latitudeDelta: 0.20,
            longitudeDelta: 0.30
        )
        precondition(tokyo != nil)
        precondition(abs(tokyo!.minLat - 35.58) < 0.000001)
        precondition(abs(tokyo!.maxLat - 35.78) < 0.000001)
        precondition(abs(tokyo!.minLon - 139.55) < 0.000001)
        precondition(abs(tokyo!.maxLon - 139.85) < 0.000001)

        precondition(ScanLabMapQueryPolicy.boundingBox(
            centerLatitude: 0,
            centerLongitude: 0,
            latitudeDelta: 180,
            longitudeDelta: 360
        ) == nil, "world-sized viewport must not exceed backend bbox limits")

        precondition(ScanLabMapQueryPolicy.boundingBox(
            centerLatitude: 35,
            centerLongitude: 179,
            latitudeDelta: 1,
            longitudeDelta: 4
        ) == nil, "antimeridian crossing needs a split query and must fail closed for now")

        precondition(ScanLabMapQueryPolicy.boundingBox(
            centerLatitude: 35,
            centerLongitude: 139,
            latitudeDelta: 0,
            longitudeDelta: 1
        ) == nil, "zero-area regions must not trigger requests")

        precondition(ScanLabMapQueryPolicy.boundingBox(
            centerLatitude: .nan,
            centerLongitude: 139,
            latitudeDelta: 1,
            longitudeDelta: 1
        ) == nil, "non-finite camera state must fail closed")

        print("PASS: ScanLab Map viewport query policy")
    }
}
