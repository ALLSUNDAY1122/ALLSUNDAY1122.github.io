import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: StoreKitManager

    var body: some View {
        WebView(store: store)
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
