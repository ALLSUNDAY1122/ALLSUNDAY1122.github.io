import Foundation

/// Copies the external resources referenced by an OBJ into the transient export workspace.
/// Returned URLs are meant to be shared alongside the exported OBJ so AirDrop/Files recipients
/// receive the MTL and texture instead of a geometrically valid but visually untextured model.
enum MeshOBJShareBundle {
    enum BundleError: LocalizedError {
        case unsafeReference(String)
        case missingReference(String)

        var errorDescription: String? {
            switch self {
            case .unsafeReference(let path):
                return "OBJが安全でない外部ファイルを参照しています: \(path)"
            case .missingReference(let path):
                return "OBJの外部ファイルが見つかりません: \(path)"
            }
        }
    }

    private static let scanChunkBytes = 64 * 1024
    private static let maxDirectiveLineBytes = 64 * 1024

    static func copyCompanions(sourceOBJ: URL, workspace: URL) throws -> [URL] {
        try Task.checkCancellation()
        guard sourceOBJ.pathExtension.lowercased() == "obj" else { return [] }
        let root = sourceOBJ.deletingLastPathComponent().standardizedFileURL
        let mtlReferences = try materialLibraryReferences(sourceOBJ: sourceOBJ)

        var shared: [URL] = []
        var copied = Set<String>()
        var sharedPaths = Set<String>()
        for reference in mtlReferences {
            try Task.checkCancellation()
            let mtlSource = try resolved(reference, relativeTo: root, allowedRoot: root)
            let mtlDestination = try copyPreservingRelativePath(
                mtlSource,
                root: root,
                workspace: workspace,
                copied: &copied
            )
            if sharedPaths.insert(mtlDestination.path).inserted {
                shared.append(mtlDestination)
            }

            let mtlRoot = mtlSource.deletingLastPathComponent()
            for textureReference in try textureReferences(sourceMTL: mtlSource) {
                try Task.checkCancellation()
                let textureSource = try resolved(textureReference, relativeTo: mtlRoot, allowedRoot: root)
                let destination = try copyPreservingRelativePath(
                    textureSource,
                    root: root,
                    workspace: workspace,
                    copied: &copied
                )
                if sharedPaths.insert(destination.path).inserted {
                    shared.append(destination)
                }
            }
        }
        try Task.checkCancellation()
        return shared
    }

    /// Returns the on-disk bytes that an exact OBJ share will additionally copy into the transient
    /// workspace. De-duplicate repeated material/texture references so storage admission matches
    /// the actual copy path rather than pessimistically counting the same companion many times.
    static func referencedCompanionByteCount(sourceOBJ: URL) throws -> Int64 {
        try Task.checkCancellation()
        guard sourceOBJ.pathExtension.lowercased() == "obj" else { return 0 }
        let root = sourceOBJ.deletingLastPathComponent().standardizedFileURL
        let mtlReferences = try materialLibraryReferences(sourceOBJ: sourceOBJ)

        var sources = Set<String>()
        var total: Int64 = 0
        func addSize(_ url: URL) throws {
            try Task.checkCancellation()
            guard sources.insert(url.standardizedFileURL.path).inserted else { return }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (attributes[.type] as? FileAttributeType) == .typeRegular,
                  let number = attributes[.size] as? NSNumber else {
                throw BundleError.missingReference(url.path)
            }
            let bytes = max(0, number.int64Value)
            total = total > Int64.max - bytes ? Int64.max : total + bytes
        }

        for reference in mtlReferences {
            try Task.checkCancellation()
            let mtlSource = try resolved(reference, relativeTo: root, allowedRoot: root)
            try addSize(mtlSource)
            let mtlRoot = mtlSource.deletingLastPathComponent()
            for textureReference in try textureReferences(sourceMTL: mtlSource) {
                try Task.checkCancellation()
                try addSize(try resolved(textureReference, relativeTo: mtlRoot, allowedRoot: root))
            }
        }
        try Task.checkCancellation()
        return total
    }

    /// Scans only bounded line buffers instead of materializing a potentially very large OBJ/MTL
    /// text file. Oversized nonstandard directive lines are ignored rather than growing memory
    /// without bound; normal Wavefront exporter directives are orders of magnitude smaller.
    private static func forEachBoundedLine(in url: URL, body: (String) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var line = Data()
        line.reserveCapacity(256)
        var discardingOversizedLine = false

        func consumeLine() {
            defer {
                line.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
            }
            guard !discardingOversizedLine, !line.isEmpty else { return }
            body(String(decoding: line, as: UTF8.self))
        }

        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: scanChunkBytes), !chunk.isEmpty else { break }
            for byte in chunk {
                if byte == 0x0A {
                    consumeLine()
                } else if !discardingOversizedLine {
                    if line.count < maxDirectiveLineBytes {
                        line.append(byte)
                    } else {
                        line.removeAll(keepingCapacity: true)
                        discardingOversizedLine = true
                    }
                }
            }
        }
        if !line.isEmpty || discardingOversizedLine { consumeLine() }
        try Task.checkCancellation()
    }

    private static func materialLibraryReferences(sourceOBJ: URL) throws -> [String] {
        var references: [String] = []
        try forEachBoundedLine(in: sourceOBJ) { line in
            let parts = parseArguments(line)
            guard parts.count >= 2, parts[0].lowercased() == "mtllib" else { return }
            references.append(contentsOf: parts.dropFirst())
        }
        return references
    }

    private static func textureReferences(sourceMTL: URL) throws -> [String] {
        let commands: Set<String> = [
            "map_ka", "map_kd", "map_ks", "map_ke", "map_d",
            "map_bump", "bump", "disp", "decal", "norm", "map_pr", "map_pm"
        ]
        var references: [String] = []
        try forEachBoundedLine(in: sourceMTL) { line in
            let parts = parseArguments(line)
            guard parts.count >= 2, commands.contains(parts[0].lowercased()),
                  let path = texturePath(in: Array(parts.dropFirst())) else { return }
            references.append(path)
        }
        return references
    }

    /// OBJ/MTL paths are frequently quoted when exported by DCC tools because material and
    /// texture names contain spaces. Preserve quoted/escaped paths instead of splitting them
    /// into lossy whitespace tokens. A comment begins only outside a quoted argument.
    private static func parseArguments(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        func flush() {
            guard !current.isEmpty else { return }
            result.append(current)
            current.removeAll(keepingCapacity: true)
        }

        for character in text {
            if escaping {
                if character.isWhitespace || character == "\"" || character == "'" || character == "\\" || character == "#" {
                    current.append(character)
                } else {
                    current.append("\\")
                    current.append(character)
                }
                escaping = false
                continue
            }
            if character == "\\" {
                escaping = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                continue
            }
            if character == "#" {
                break
            }
            if character.isWhitespace {
                flush()
            } else {
                current.append(character)
            }
        }
        if escaping { current.append("\\") }
        flush()
        return result
    }

    private static func texturePath(in arguments: [String]) -> String? {
        var index = 0
        while index < arguments.count, arguments[index].hasPrefix("-") {
            let option = arguments[index].lowercased()
            index += 1
            switch option {
            case "-mm":
                index = min(arguments.count, index + 2)
            case "-o", "-s", "-t":
                var consumed = 0
                while index < arguments.count, consumed < 3, Float(arguments[index]) != nil {
                    index += 1
                    consumed += 1
                }
            default:
                if index < arguments.count { index += 1 }
            }
        }
        guard index < arguments.count else { return nil }
        let path = arguments[index...].joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private static func resolved(_ reference: String, relativeTo base: URL, allowedRoot: URL) throws -> URL {
        let characters = Array(reference)
        let isWindowsAbsolute = characters.count >= 3 && characters[1] == ":" && (characters[2] == "\\" || characters[2] == "/")
        guard !reference.hasPrefix("/"), !reference.hasPrefix("~"), !isWindowsAbsolute else {
            throw BundleError.unsafeReference(reference)
        }
        let normalizedReference = reference.replacingOccurrences(of: "\\", with: "/")
        let lexicalCandidate = base.appendingPathComponent(normalizedReference).standardizedFileURL
        let lexicalRoot = allowedRoot.standardizedFileURL
        guard isContained(lexicalCandidate, in: lexicalRoot) else {
            throw BundleError.unsafeReference(reference)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: lexicalCandidate.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw BundleError.missingReference(reference)
        }

        let rootPath = lexicalRoot.path.hasSuffix("/") ? lexicalRoot.path : lexicalRoot.path + "/"
        let relative = String(lexicalCandidate.path.dropFirst(rootPath.count))
        guard !relative.isEmpty else { throw BundleError.unsafeReference(reference) }
        let resolvedRoot = lexicalRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = lexicalCandidate.resolvingSymlinksInPath().standardizedFileURL
        let expectedResolved = resolvedRoot.appendingPathComponent(relative).standardizedFileURL
        guard resolvedCandidate == expectedResolved,
              isContained(resolvedCandidate, in: resolvedRoot) else {
            throw BundleError.unsafeReference(reference)
        }
        return lexicalCandidate
    }

    private static func isContained(_ candidate: URL, in root: URL) -> Bool {
        if candidate.standardizedFileURL == root.standardizedFileURL { return true }
        let rootPath = root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path
            : root.standardizedFileURL.path + "/"
        return candidate.standardizedFileURL.path.hasPrefix(rootPath)
    }

    private static func copyPreservingRelativePath(
        _ source: URL,
        root: URL,
        workspace: URL,
        copied: inout Set<String>
    ) throws -> URL {
        try Task.checkCancellation()
        let source = source.standardizedFileURL
        let root = root.standardizedFileURL
        guard isContained(source, in: root) else {
            throw BundleError.unsafeReference(source.path)
        }
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let relative = String(source.path.dropFirst(rootPath.count))
        guard !relative.isEmpty else { throw BundleError.unsafeReference(source.path) }
        let destination = workspace.appendingPathComponent(relative).standardizedFileURL

        if source == destination {
            copied.insert(destination.path)
            return destination
        }

        if copied.insert(destination.path).inserted {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            try Task.checkCancellation()
        }
        return destination
    }
}
