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
        guard FileManager.default.createFile(atPath: destinationURL.path, contents: nil) else {
            throw error("編集結果を作成できません")
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }

        var committed = false
        var replaced = false
        var output = Data()
        output.reserveCapacity(outputBufferLimit)
        defer {
            try? handle.close()
            if !committed { try? FileManager.default.removeItem(at: destinationURL) }
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

        try forEachLine(at: sourceURL) { line in
            if directiveValue(in: line, directive: directive) != nil {
                try append("\(directive) \(replacement)")
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
        guard line[start..<end] == directive[...] else { return nil }

        var valueStart = end
        while valueStart < line.endIndex, line[valueStart].isWhitespace {
            line.formIndex(after: &valueStart)
        }
        guard valueStart < line.endIndex else { return nil }
        let value = line[valueStart...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
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
