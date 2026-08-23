#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct BookPackageDocumentExporter: UIViewControllerRepresentable {
    public let packageURL: URL
    public let completion: @MainActor (Bool) -> Void

    public init(packageURL: URL, completion: @escaping @MainActor (Bool) -> Void) {
        self.packageURL = packageURL
        self.completion = completion
    }

    public func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [packageURL], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: @MainActor (Bool) -> Void
        init(completion: @escaping @MainActor (Bool) -> Void) { self.completion = completion }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in completion(!urls.isEmpty) }
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Task { @MainActor in completion(false) }
        }
    }
}
#endif
