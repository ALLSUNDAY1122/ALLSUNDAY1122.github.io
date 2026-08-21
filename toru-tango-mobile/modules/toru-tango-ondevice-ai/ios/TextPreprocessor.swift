import Foundation

enum TextPreprocessor {
  static func clean(_ text: String) -> String {
    let normalized = text
      .precomposedStringWithCompatibilityMapping
      .replacingOccurrences(of: "\u{00A0}", with: " ")
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let lines = normalized
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .map(cleanLine)
      .filter(isUsefulLine)

    var deduplicated: [String] = []
    var seen = Set<String>()

    for line in lines {
      let key = line.lowercased().replacingOccurrences(of: " ", with: "")
      guard !key.isEmpty, !seen.contains(key) else { continue }
      seen.insert(key)
      deduplicated.append(line)
    }

    return deduplicated
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func cleanLine(_ line: String) -> String {
    line
      .replacingOccurrences(
        of: #"[ \t　]+"#,
        with: " ",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"^[\s\-_=・●○■□◆◇※*]+|[\s\-_=・●○■□◆◇]+$"#,
        with: "",
        options: .regularExpression
      )
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func isUsefulLine(_ line: String) -> Bool {
    guard line.count >= 3 else { return false }
    let meaningful = line.unicodeScalars.filter {
      CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
    }
    guard meaningful.count >= 3 else { return false }
    let symbolCount = line.unicodeScalars.filter {
      CharacterSet.symbols.contains($0) || CharacterSet.punctuationCharacters.contains($0)
    }.count
    return Double(symbolCount) / Double(max(line.unicodeScalars.count, 1)) < 0.65
  }
}
