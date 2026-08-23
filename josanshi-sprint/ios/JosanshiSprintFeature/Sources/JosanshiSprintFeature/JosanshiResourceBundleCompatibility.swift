#if !SWIFT_PACKAGE
import Foundation

private final class JosanshiResourceBundleCompatibilityMarker {}

extension Bundle {
    static var module: Bundle {
        Bundle(for: JosanshiResourceBundleCompatibilityMarker.self)
    }
}
#endif
