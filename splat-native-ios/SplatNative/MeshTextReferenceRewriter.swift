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
                if (normalizedDirective == "map_kd" || normalizedDirective == "mtllib"), replaced {
                    try append(rebasedReferenceLine(
                        line,
                        directive: directive,
                        sourceURL: source,
                        destinationURL: destination
                    ))
                    return true
                }

                if normalizedDirective == "map_kd" {
                    let arguments = parseArguments(String(line))
                    let payload = Array(arguments.dropFirst())
                    if let pathStart = texturePathStartIndex(in: payload) {
                        let options = payload[..<pathStart]
                        let optionSuffix = options.isEmpty ? "" : " " + options.joined(separator: " ")
                        try append("\(directive)\(optionSuffix) \(replacement)")
                    } else {
                        try append("\(directive) \(replacement)")
                    }
                } else if normalizedDirective == "mtllib", hasExplicitQuotedReferenceList(String(line)) {
                    let arguments = parseArguments(String(line))
                    let retained = arguments.dropFirst(2).map {
                        renderReferenceArgument(rebasedReference(
                            $0,
                            sourceURL: source,
                            destinationURL: destination
                        ))
                    }
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
        if normalizedDirective == "map_kd" {
            let arguments = parseArguments(String(line[start...]))
            guard arguments.count >= 2,
                  let path = texturePath(in: Array(arguments.dropFirst())) else { return nil }
            return normalizedRelativeReference(path)
        }

        if normalizedDirective == "mtllib" {
            let raw = String(line[start...])
            let arguments = parseArguments(raw)
            if arguments.count == 2 || hasExplicitQuotedReferenceList(raw), arguments.count >= 2 {
                return normalizedRelativeReference(arguments[1])
            }
            let legacyValue = stripUnquotedInlineComment(String(line[valueStart...]))
                .trimmingCharacters(in: .whitespaces)
            return legacyValue.isEmpty ? nil : legacyValue
        }

        let value = line[valueStart...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func rebasedReferenceLine(
        _ line: Substring,
        directive: String,
        sourceURL: URL,
        destinationURL: URL
    ) -> String {
        let normalizedDirective = directive.lowercased()
        let lineString = String(line)

        if normalizedDirective == "map_kd" {
            let arguments = parseArguments(lineString)
            let payload = Array(arguments.dropFirst())
            guard let pathStart = texturePathStartIndex(in: payload) else { return lineString }
            let options = payload[..<pathStart]
            let optionSuffix = options.isEmpty ? "" : " " + options.joined(separator: " ")
            let path = payload[pathStart...].joined(separator: " ")
            let rebased = renderReferenceArgument(rebasedReference(
                path,
                sourceURL: sourceURL,
                destinationURL: destinationURL
            ))
            return "\(directive)\(optionSuffix) \(rebased)"
        }

        if normalizedDirective == "mtllib" {
            if hasExplicitQuotedReferenceList(lineString) {
                let arguments = parseArguments(lineString)
                let libraries = arguments.dropFirst().map {
                    renderReferenceArgument(rebasedReference(
                        $0,
                        sourceURL: sourceURL,
                        destinationURL: destinationURL
                    ))
                }
                guard !libraries.isEmpty else { return lineString }
                return "\(directive) \(libraries.joined(separator: " "))"
            }
            guard let reference = directiveValue(in: line, directive: directive) else { return lineString }
            return "\(directive) \(renderReferenceArgument(rebasedReference(
                reference,
                sourceURL: sourceURL,
                destinationURL: destinationURL
            )))"
        }

        return lineString
    }

    private static func rebasedReference(
        _ reference: String,
        sourceURL: URL,
        destinationURL: URL
    ) -> String {
        let normalized = normalizedRelativeReference(reference)
        guard !normalized.hasPrefix("/") else { return normalized }

        let target = sourceURL.deletingLastPathComponent()
            .appendingPathComponent(normalized)
            .standardizedFileURL
        let destinationDirectory = destinationURL.deletingLastPathComponent().standardizedFileURL
        let baseComponents = destinationDirectory.pathComponents
        let targetComponents = target.pathComponents
        var common = 0
        while common < baseComponents.count,
              common < targetComponents.count,
              baseComponents[common] == targetComponents[common] {
            common += 1
        }
        guard common > 0 else { return target.path }

        let upward = Array(repeating: "..", count: baseComponents.count - common)
        let downward = Array(targetComponents.dropFirst(common))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
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

    private static func stripUnquotedInlineComment(_ text: String) -> String {
        var escaping = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "#" {
                return String(text[..<index])
            }
            text.formIndex(after: &index)
        }
        return text
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
