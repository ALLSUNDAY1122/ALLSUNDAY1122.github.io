import Foundation

@main
enum L3AW52SessionBindingSelfTest {
    static func main() throws {
        precondition(
            try Lane3CandidatePhysicalResourceTraceAccumulator
                .validatedSessionIdentifier("aw52-session") == "aw52-session"
        )
        for invalid in ["", " aw52-session", "aw52-session ", "\naw52-session", String(repeating: "x", count: 129)] {
            do {
                _ = try Lane3CandidatePhysicalResourceTraceAccumulator
                    .validatedSessionIdentifier(invalid)
                preconditionFailure("invalid session identifier escaped: \(String(reflecting: invalid))")
            } catch Lane3CandidatePhysicalResourceTraceError.invalidSessionIdentifier {
                continue
            }
        }
        print("L3_AW52_SessionBindingSelfTest PASS")
    }
}
