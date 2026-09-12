import Foundation

enum PublicBrowsePolicy {
    static func isBrowsable(_ scan: ScanLabPublicScan) -> Bool {
        scan.visibility == "public" && scan.author != nil
    }

    static func scans(for authorID: UUID, in scans: [ScanLabPublicScan]) -> [ScanLabPublicScan] {
        scans
            .filter { $0.author?.id == authorID && isBrowsable($0) }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    static func author(for scan: ScanLabPublicScan) -> ScanLabAuthor? {
        guard isBrowsable(scan) else { return nil }
        return scan.author
    }
}
