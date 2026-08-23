import CryptoKit
import Foundation
import HQGoldenSupport

@main
enum HQGoldenFinalizerCLI {
    static func main() throws {
        let arguments = try parseArguments(CommandLine.arguments)
        let executionURL = URL(fileURLWithPath: arguments.executionReport)
        let executionData = try Data(contentsOf: executionURL)
        let execution = try JSONDecoder().decode(FormalGoldenExecutionSnapshot.self, from: executionData)
        let executionSHA = sha256(executionData)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let templatePath = arguments.createTemplate {
            let review = FormalGoldenReviewFinalizer.makeTemplate(
                execution: execution,
                executionReportSHA256: executionSHA
            )
            let data = try encoder.encode(review)
            let destination = URL(fileURLWithPath: templatePath)
            try data.write(to: destination, options: .atomic)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return
        }

        guard let reviewPath = arguments.reviewDecisions else {
            throw CLIError.invalidArguments(usage)
        }
        let review = try JSONDecoder().decode(
            FormalGoldenHumanReview.self,
            from: Data(contentsOf: URL(fileURLWithPath: reviewPath))
        )
        let assessment = FormalGoldenReviewFinalizer.evaluate(
            execution: execution,
            executionReportSHA256: executionSHA,
            review: review
        )
        let data = try encoder.encode(assessment)
        let destination = arguments.output.map(URL.init(fileURLWithPath:))
            ?? executionURL.deletingLastPathComponent().appendingPathComponent("hq-formal-golden-final.json")
        try data.write(to: destination, options: .atomic)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private struct Arguments {
        let executionReport: String
        let createTemplate: String?
        let reviewDecisions: String?
        let output: String?
    }

    private enum CLIError: Error, LocalizedError {
        case invalidArguments(String)

        var errorDescription: String? {
            switch self {
            case .invalidArguments(let message): return message
            }
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> Arguments {
        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                throw CLIError.invalidArguments(usage)
            }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard let execution = values["--execution-report"] else {
            throw CLIError.invalidArguments(usage)
        }
        let template = values["--create-template"]
        let review = values["--review-decisions"]
        guard (template != nil) != (review != nil) else {
            throw CLIError.invalidArguments("Specify exactly one of --create-template or --review-decisions.\n\(usage)")
        }
        return Arguments(
            executionReport: execution,
            createTemplate: template,
            reviewDecisions: review,
            output: values["--output"]
        )
    }

    private static var usage: String {
        "Usage: scanner-hq-golden-finalizer --execution-report <hq-golden-execution.json> (--create-template <review-decisions.json> | --review-decisions <review-decisions.json>) [--output <hq-formal-golden-final.json>]"
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
