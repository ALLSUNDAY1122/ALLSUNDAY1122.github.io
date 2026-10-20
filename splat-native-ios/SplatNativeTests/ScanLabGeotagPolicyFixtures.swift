import Foundation

struct ScanLabLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let label: String?
}

enum ScanLabVisibility: String, CaseIterable, Identifiable, Codable {
    case `private`
    case unlisted
    case `public`
    var id: String { rawValue }
}
