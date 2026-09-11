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

    static func copyCompanions(sourceOBJ: URL, workspace: URL) throws -> [URL] {
        guard sourceOBJ.pathExtension.lowercased() == "obj" else { return [] }
        let root = sourceOBJ.deletingLastPathComponent().standardizedFileURL
        let text = try String(contentsOf: sourceOBJ, encoding: .utf8)
        let mtlReferences = text
            .split(whereSeparator: { $0.isNewline })
            .flatMap { line -> [String] in
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                guard trimmed.lowercased().hasPrefix("mtllib ") else { return [] }
                return parseArguments(String(trimmed.dropFirst("mtllib ".count)))
            }

        var shared: [URL] = []
        var copied = Set<String>()
        var sharedPaths = Set<String>()
        for reference in mtlReferences {
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

            let mtlText = try String(contentsOf: mtlSource, encoding: .utf8)
            let mtlRoot = mtlSource.deletingLastPathComponent()
            for textureReference in textureReferences(in: mtlText) {
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
        return shared
    }

    private static func textureReferences(in mtl: String) -> [String] {
        let commands: Set<String> = [
            "map_ka", "map_kd", "map_ks", "map_ke", "map_d",
            "map_bump", "bump", "disp", "decal", "norm", "map_pr", "map_pm"
        ]
        return mtl.split(whereSeparator: { $0.isNewline }).compactMap { rawLine in
            let parts = parseArguments(String(rawLine))
            guard parts.count >= 2, commands.contains(parts[0].lowercased()) else { return nil }
            return texturePath(in: Array(parts.dropFirst()))
        }
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
                    // A backslash before an ordinary filename character is a Windows path
                    // separator, not an OBJ escape sequence. Preserve it for normalization.
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

    /// MTL texture statements can prefix the filename with mapping options. Consume the known
    /// option payload, then preserve all remaining tokens as the filename. This handles both
    /// quoted filenames and exporters that emit an unquoted path containing spaces.
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
                // All remaining standard map options take one value. For unknown options, one
                // value is the least-lossy interpretation and leaves the eventual path intact.
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

        // OBJ/MTL files created on Windows commonly persist '\\' separators. Normalize only
        // after rejecting an absolute drive path; parent traversal is still caught below after
        // standardizedFileURL resolves `..` components.
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

        // Compare the candidate after resolving against the same relative path under the resolved
        // project root. This tolerates iOS sandbox ancestors such as /var -> /private/var while
        // rejecting any symlink introduced inside the project itself (which would either escape
        // the project or change a referenced filename when the files are shared).
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
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return destination
    }
}
