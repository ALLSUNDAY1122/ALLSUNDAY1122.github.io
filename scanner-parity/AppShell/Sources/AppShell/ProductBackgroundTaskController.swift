#if canImport(UIKit)
import UIKit

@MainActor
public final class ProductBackgroundTaskController {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var expirationHandler: (() -> Void)?

    public init() {}

    public func begin(expiration: @escaping () -> Void) {
        end()
        expirationHandler = expiration
        identifier = UIApplication.shared.beginBackgroundTask(withName: "ScannerParityProcessing") { [weak self] in
            guard let self else { return }
            self.expirationHandler?()
            self.end()
        }
    }

    public func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
        expirationHandler = nil
    }
}
#endif
