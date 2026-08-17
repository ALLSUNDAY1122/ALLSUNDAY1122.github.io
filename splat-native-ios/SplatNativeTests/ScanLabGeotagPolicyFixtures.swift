import Foundation

// Test-target mirrors for the policy's value types. Keeping these fixtures in the
// test module lets the privacy policy compile without pulling the full Supabase-backed
// ScanLabBackend into the unit-test target.
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
