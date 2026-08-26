import Foundation

// HQ integration compatibility shim for Swift 6.0.x.
// The W46 adjudication code compares a six-String tuple lexicographically.
// Providing the exact overload avoids an expensive generic tuple-comparison
// solver path while preserving the same ordering semantics.
typealias AnalysisIssueSortTuple = (String, String, String, String, String, String)

func < (lhs: AnalysisIssueSortTuple, rhs: AnalysisIssueSortTuple) -> Bool {
    if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
    if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
    if lhs.2 != rhs.2 { return lhs.2 < rhs.2 }
    if lhs.3 != rhs.3 { return lhs.3 < rhs.3 }
    if lhs.4 != rhs.4 { return lhs.4 < rhs.4 }
    return lhs.5 < rhs.5
}
