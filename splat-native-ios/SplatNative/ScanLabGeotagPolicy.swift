import Foundation

enum ScanLabGeotagPolicy {
    static func normalized(visibility: ScanLabVisibility, location: ScanLabLocation?, label: String?) -> ScanLabLocation? {
        guard visibility == .public, let location else { return nil }
        guard location.latitude.isFinite, location.longitude.isFinite,
              (-90.0...90.0).contains(location.latitude), (-180.0...180.0).contains(location.longitude) else { return nil }
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeLabel = (trimmed?.isEmpty == false) ? String(trimmed!.prefix(80)) : nil
        return ScanLabLocation(latitude: location.latitude, longitude: location.longitude, label: safeLabel)
    }
    static func canPublishPublic(location: ScanLabLocation?, publicPlaceConfirmed: Bool, privacyConfirmed: Bool, rightsConfirmed: Bool) -> Bool {
        guard privacyConfirmed, rightsConfirmed else { return false }
        guard let location else { return true }
        return normalized(visibility: .public, location: location, label: location.label) != nil && publicPlaceConfirmed
    }
}
