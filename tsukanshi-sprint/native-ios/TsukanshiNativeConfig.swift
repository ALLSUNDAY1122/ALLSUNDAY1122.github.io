import Foundation
import LearningSprintCore

public enum TsukanshiNativeConfig {
    public static let bundleID = "jp.allsunday1122.tsukanshi"
    public static let appStoreConnectID = "6799753744"
    public static let codemagicProfile = "tsukanshi_appstore"
    public static let productID = "jp.allsunday1122.tsukanshi.premium"
    public static let teamID = "MN3D2ZM44N"
    public static let version = "1.0.0"
    public static let subjects = ["通関業法", "関税法等", "通関実務"]
    public static let examRounds = ["第59回", "第58回", "第57回"]
    public static let mockQuestionCountBySubject = ["通関業法": 17, "関税法等": 28, "通関実務": 16]

    public static let qualification = QualificationConfig(
        qualificationName: "通関士",
        appDisplayName: "通関士｜学びスプリント",
        bundleID: bundleID,
        appStoreConnectID: appStoreConnectID,
        codemagicProfile: codemagicProfile,
        productID: productID,
        version: version,
        teamID: teamID,
        subjects: subjects,
        defaultExamDate: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 4))
    )

    public static let officialExamURLs: [String: URL] = [
        "第59回": URL(string: "https://www.customs.go.jp/tsukanshi/59_shiken/59shikenkaito.html")!,
        "第58回": URL(string: "https://www.customs.go.jp/tsukanshi/58_shiken/58shikenkaito.html")!,
        "第57回": URL(string: "https://www.customs.go.jp/tsukanshi/57_shiken/57shikenkaito.html")!
    ]
}
