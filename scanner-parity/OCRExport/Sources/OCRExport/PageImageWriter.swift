import Foundation

#if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import ImageIO
import UniformTypeIdentifiers
#endif

public enum PageImageWriterError: Error, LocalizedError {
    case decodeFailed
    case destinationCreateFailed
    case encodeFailed

    public var errorDescription: String? {
        switch self {
        case .decodeFailed: return "Page image could not be decoded."
        case .destinationCreateFailed: return "JPEG destination could not be created."
        case .encodeFailed: return "Page image could not be encoded as JPEG."
        }
    }
}

public enum PageImageWriter {
    public static func writeJPEG(sourceURL: URL, destinationURL: URL) throws {
        #if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PageImageWriterError.decodeFailed
        }
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PageImageWriterError.destinationCreateFailed
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw PageImageWriterError.encodeFailed
        }
        #else
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        #endif
    }
}
