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
            .compactMap { line -> String? in
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("mtllib ") else { return nil }
                let value = String(trimmed.dropFirst("mtllib ".count))
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }

        var shared: [URL] = []
        var copied = Set<String>()
        for reference in mtlReferences {
            let mtlSource = try resolved(reference, relativeTo: root, allowedRoot: root)
            let mtlDestination = try copyPreservingRelativePath(
                mtlSource,
                root: root,
                workspace: workspace,
                copied: &copied
            )
            shared.append(mtlDestination)

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
                shared.append(destination)
            }
        }
        return shared
    }

    private static func textureReferences(in mtl: String) -> [String] {
        let commands: Set<String> = [
            "map_Ka", "map_Kd", "map_Ks", "map_Ke", "map_d",
            "map_bump", "bump", "disp", "decal", "norm", "map_Pr", "map_Pm"
        ]
        return mtl.split(whereSeparator: { $0.isNewline }).compactMap { rawLine in
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2, commands.contains(String(parts[0])), let last = parts.last else {
                return nil
            }
            return String(last)
        }
    }

    private static func resolved(_ reference: String, relativeTo base: URL, allowedRoot: URL) throws -> URL {
        guard !reference.hasPrefix("/"), !reference.hasPrefix("~") else {
            throw BundleError.unsafeReference(reference)
        }
        let lexicalCandidate = base.appendingPathComponent(reference).standardizedFileURL
        let lexicalRoot = allowedRoot.standardizedFileURL
        guard isContained(lexicalCandidate, in: lexicalRoot) else {
            throw BundleError.unsafeReference(reference)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: lexicalCandidate.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw BundleError.missingReference(reference)
        }

        // Standardized paths only collapse `..`; resolve symlinks as well so an imported OBJ
        // cannot smuggle a companion outside its project directory through an in-tree symlink.
        let resolvedRoot = lexicalRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = lexicalCandidate.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(resolvedCandidate, in: resolvedRoot) else {
            throw BundleError.unsafeReference(reference)
        }
        return resolvedCandidate
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
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(resolvedSource, in: resolvedRoot) else {
            throw BundleError.unsafeReference(source.path)
        }
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        let relative = String(resolvedSource.path.dropFirst(rootPath.count))
        guard !relative.isEmpty else { throw BundleError.unsafeReference(source.path) }
        let destination = workspace.appendingPathComponent(relative).standardizedFileURL

        if resolvedSource == destination.resolvingSymlinksInPath().standardizedFileURL {
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
            try FileManager.default.copyItem(at: resolvedSource, to: destination)
        }
        return destination
    }
}
