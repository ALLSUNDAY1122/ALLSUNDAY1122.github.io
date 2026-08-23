import Foundation
import LearningSprintCore

enum KanriAppConfig {
    static let qualificationName = "管理栄養士国家試験"
    static let displayName = "管理栄養士 学びスプリント"
    static let bundleID = "jp.allsunday1122.kanrieiyoushi"
    static let appStoreConnectID = "6799753841"
    static let codemagicProfile = "kanrieiyoushi_appstore"
    static let productID = "jp.allsunday1122.kanrieiyoushi.premium"
    static let contentVersion = "kanri-native-600-v1"
    static let version = "1.0.0"
    static let subjects = ["社会・環境","人体・疾病","食べ物","基礎栄養","応用栄養","栄養教育","臨床栄養","公衆栄養","給食経営","応用力"]
    static let expectedPerRound: [String:Int] = ["社会・環境":16,"人体・疾病":26,"食べ物":25,"基礎栄養":14,"応用栄養":16,"栄養教育":13,"臨床栄養":26,"公衆栄養":16,"給食経営":18,"応用力":30]
    static let qualificationConfig = QualificationConfig(qualificationName: qualificationName, appDisplayName: displayName, bundleID: bundleID, appStoreConnectID: appStoreConnectID, codemagicProfile: codemagicProfile, productID: productID, version: version, subjects: subjects)
    static var uiTestPremium: Bool { ProcessInfo.processInfo.arguments.contains("-UITestPremium") }
}

enum MainTab: Hashable { case home, mock, history, settings }
enum FontChoice: Int, CaseIterable, Identifiable {
    case small=0, normal=1, large=2
    var id: Int { rawValue }
    var title: String { switch self { case .small: "小"; case .normal: "標準"; case .large: "大" } }
}
