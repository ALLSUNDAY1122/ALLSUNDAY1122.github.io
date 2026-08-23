#if canImport(SwiftUI)
import SwiftUI
import ProductFlow

@MainActor
public final class ProductFlowStore: ObservableObject {
    @Published public private(set) var state: ProductFlowState

    public init(state: ProductFlowState = .init()) {
        self.state = state
    }

    public func send(_ action: ProductFlowAction) {
        ProductFlowReducer.reduce(state: &state, action: action)
    }
}
#endif
