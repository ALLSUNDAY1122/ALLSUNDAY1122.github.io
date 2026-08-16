import SwiftUI

struct ScanLabDiscoverShellView: View {
    var body: some View {
        TabView {
            ScanLabScanTab().tabItem { Label("Scan", systemImage: "viewfinder") }
            ScanLabMapView().tabItem { Label("Map", systemImage: "map") }
            ScanLabPagedDiscoverView().tabItem { Label("Discover", systemImage: "sparkles.rectangle.stack") }
            ScanLabAccountView().tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(.mint)
        .preferredColorScheme(.dark)
    }
}
