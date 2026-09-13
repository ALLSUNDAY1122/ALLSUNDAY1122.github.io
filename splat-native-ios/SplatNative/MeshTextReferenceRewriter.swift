import Foundation

enum MeshTextReferenceRewriter {
    private static let inputChunkSize = 256 * 1024
    private static let outputBufferLimit = 256 * 1024
    private static let maximumLineBytes = 8 * 1024 * 1024

    static func firstReference(in url: URL, directive: String) throws -> String? {
        var result: String?
        try forEachLine(at: url) { line in
            guard result == nil else { return false }
            guard let value = directiveValue(in: line, directive: directive) else { return true }
            result = value
            return false
        }
        return result
    }

    @discardableResult
    static func rewrite(
        sourceURL: URL,
        destinationURL: URL,
        directive: String,
        replacement: String
    ) throws -> Bool {
        guard !replacement.isEmpty,
              !replacement.contains("\n"),
              !replacement.contains("\r") else {
            throw error("参照名が不正です")
        }
        let source = sourceURL.standardizedFileURL
        let destination = destinationURL.standardizedFileURL
        guard source != destination,
              !FileManager.default.fileExists(atPath: destination.path) else {
            throw error("編集先が既存ファイルと競合しています")
        }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw error("編集結果を作成できません")
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        var committed = false
        var replaced = false
        var output = Data()
        output.reserveCapacity(outputBufferLimit)
        defer {
            try? handle.close()
            if !committed { try? FileManager.default.removeItem(at: destination) }
        }

        func flush() throws {
            guard !output.isEmpty else { return }
            try handle.write(contentsOf: output)
            output.removeAll(keepingCapacity: true)
        }

        func append(_ string: String) throws {
            output.append(contentsOf: string.utf8)
            output.append(0x0A)
            if output.count >= outputBufferLimit { try flush() }
        }

        let normalizedDirective = directive.lowercased()
        try forEachLine(at: source) { line in
            if directiveValue(in: line, directive: directive) != nil {
                // Appearance editing materializes exactly one diffuse bitmap and one material
                // library generation. Repointing every map_Kd/mtllib reference to that generation
                // collapses unrelated materials in multi-material assets. Replace the first target
                // only and preserve all later reference lines until full multi-texture editing exists.
                if (normalizedDirective == "map_kd" || normalizedDirective == "mtllib"), replaced {
                    try append(String(line))
                    return true
                }

                if normalizedDirective == "map_kd" {
                    let arguments = parseArguments(String(line))
                    let payload = Array(arguments.dropFirst())
                    if let pathStart = texturePathStartIndex(in: payload) {
                        // Preserve material-space texture transforms/options. Dropping -s/-o/-t while
                        // swapping the edited bitmap changes how the same UVs sample the texture and
                        // can make a successful appearance edit visibly move or rescale the material.
                        let options = payload[..<pathStart]
                        let optionSuffix = options.isEmpty ? "" : " " + options.joined(separator: " ")
                        try append("\(directive)\(optionSuffix) \(replacement)")
                    } else {
                        try append("\(directive) \(replacement)")
                    }
                } else if normalizedDirective == "mtllib", hasExplicitQuotedReferenceList(String(line)) {
                    let arguments = parseArguments(String(line))
                    let retained = arguments.dropFirst(2).map(renderReferenceArgument)
                    let suffix = retained.isEmpty ? "" : " " + retained.joined(separator: " ")
                    try append("\(directive) \(replacement)\(suffix)")
                } else {
                    try append("\(directive) \(replacement)")
                }
                replaced = true
            } else {
                try append(String(line))
            }
            return true
        }
        guard replaced else { throw error("必要な参照がありません") }
        try flush()
        try handle.synchronize()
        committed = true
        return true
    }

    private static func directiveValue(in line: Substring, directive: String) -> String? {
        var start = line.startIndex
        while start < line.endIndex, line[start].isWhitespace {
            line.formIndex(after: &start)
        }
        guard start < line.endIndex, line[start] != "#" else { return nil }

        var end = start
        while end < line.endIndex, !line[end].isWhitespace {
            line.formIndex(after: &end)
        }
        guard line[start..<end].lowercased() == directive.lowercased() else { return nil }

        var valueStart = end
        while valueStart < line.endIndex, line[valueStart].isWhitespace {
            line.formIndex(after: &valueStart)
        }
        guard valueStart < line.endIndex else { return nil }

        let normalizedDirective = directive.lowercased()
        // Appearance editing needs the actual diffuse texture path, not the literal remainder of a
        // Wavefront map_Kd line. Standard exporters commonly add options such as -s/-o and quote
        // filenames containing spaces. Treating that complete suffix as one filesystem path made a
        // valid textured OBJ shareable but impossible to reopen in the appearance editor.
        if normalizedDirective == "map_kd" {
            let arguments = parseArguments(String(line[start...]))
            guard arguments.count >= 2,
                  let path = texturePath(in: Array(arguments.dropFirst())) else { return nil }
            return normalizedRelativeReference(path)
        }

        // A quoted/single mtllib reference (optionally followed by a comment) should resolve to the
        // actual filename for the appearance editor. Preserve the legacy raw remainder when an OBJ
        // supplies multiple unquoted tokens because older Scan Lab fixtures treated that text as a
        // single filename. When the exporter explicitly quotes a multi-library list, however, the
        // first quoted token is unambiguous and can be edited without discarding the later libraries.
        if normalizedDirective == "mtllib" {
            let raw = String(line[start...])
            let arguments = parseArguments(raw)
            if arguments.count == 2 || hasExplicitQuotedReferenceList(raw), arguments.count >= 2 {
                return normalizedRelativeReference(arguments[1])
            }
        }

        let value = line[valueStart...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func normalizedRelativeReference(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/")
    }

    private static func hasExplicitQuotedReferenceList(_ text: String) -> Bool {
        var escaping = false
        for character in text {
            if escaping {
                escaping = false
                continue
            }
            if character == "\\" {
                escaping = true
                continue
            }
            if character == "#" {
                return false
            }
            if character == "\"" || character == "'" {
                return true
            }
        }
        return false
    }

    private static func renderReferenceArgument(_ value: String) -> String {
        let normalized = normalizedRelativeReference(value)
        let needsQuotes = normalized.contains(where: { $0.isWhitespace || $0 == "#" || $0 == "\"" })
        guard needsQuotes else { return normalized }
        let escaped = normalized.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

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

    private static func texturePathStartIndex(in arguments: [String]) -> Int? {
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
                // Remaining standard map options (-clamp, -blendu, -blendv, -boost, -texres,
                // -bm, -imfchan, -type) each consume one value. Unknown vendor options retain the
                // same conservative one-value behavior as the exact-share parser.
                if index < arguments.count { index += 1 }
            }
        }
        return index < arguments.count ? index : nil
    }

    private static func texturePath(in arguments: [String]) -> String? {
        guard let index = texturePathStartIndex(in: arguments) else { return nil }
        let path = arguments[index...].joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private static func forEachLine(at url: URL, _ body: (Substring) throws -> Bool) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw error("参照元が安全な通常ファイルではありません")
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var buffer = Data()
        buffer.reserveCapacity(inputChunkSize * 2)

        while let chunk = try handle.read(upToCount: inputChunkSize), !chunk.isEmpty {
            buffer.append(chunk)
            var start = buffer.startIndex
            while start < buffer.endIndex,
                  let newline = buffer[start...].firstIndex(of: 0x0A) {
                var end = newline
                if end > start {
                    let previous = buffer.index(before: end)
                    if buffer[previous] == 0x0D { end = previous }
                }
                guard buffer.distance(from: start, to: end) <= maximumLineBytes else {
                    throw error("1行が大きすぎます")
                }
                guard let lineString = String(bytes: buffer[start..<end], encoding: .utf8) else {
                    throw error("UTF-8として読み込めません")
                }
                if try !body(lineString[...]) { return }
                start = buffer.index(after: newline)
            }
            if start > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<start)
            }
            guard buffer.count <= maximumLineBytes else { throw error("1行が大きすぎます") }
        }

        if !buffer.isEmpty {
            var end = buffer.endIndex
            if end > buffer.startIndex {
                let previous = buffer.index(before: end)
                if buffer[previous] == 0x0D { end = previous }
            }
            guard buffer.distance(from: buffer.startIndex, to: end) <= maximumLineBytes else {
                throw error("1行が大きすぎます")
            }
            guard let lineString = String(bytes: buffer[buffer.startIndex..<end], encoding: .utf8) else {
                throw error("UTF-8として読み込めません")
            }
            _ = try body(lineString[...])
        }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshTextReferenceRewriter", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
