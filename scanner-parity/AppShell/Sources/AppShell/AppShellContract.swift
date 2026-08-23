import ProductFlow

public enum AppShellContract {
    public static let supportedInputKinds: [ProductInputKind] = [.video, .image]
    public static let initialStep: ProductFlowStep = .selectingInput
}
