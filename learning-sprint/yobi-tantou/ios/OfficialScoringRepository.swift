import Foundation

struct OfficialScoringCanonical: Decodable, Equatable {
    let schemaVersion: Int
    let qualification: String
    let verifiedAt: String
    let years: [String: OfficialYearScoring]
}

struct OfficialYearScoring: Decodable, Equatable {
    let legal: OfficialLegalScoring
    let generalEducation: OfficialGeneralEducationScoring
    let totalMaxPoints: Int
    let officialPassScore: Int
}

struct OfficialLegalScoring: Decodable, Equatable {
    let questionCount: Int
    let maxPoints: Int
    let questions: [OfficialMockQuestionScoring]
}

struct OfficialGeneralEducationScoring: Decodable, Equatable {
    let offered: Int
    let select: Int
    let pointsPerSelectedQuestion: Int
    let maxPoints: Int
    let answerKey: [String: Int]
    let sourceURL: String
}

enum OfficialScoringRepositoryError: Error, Equatable, LocalizedError {
    case resourceMissing
    case invalidSchema(Int)
    case invalidQualification
    case missingYear(Int)
    case invalidYear(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            return "公式年度模試の採点データが見つかりません。"
        case .invalidSchema(let version):
            return "公式年度模試の採点データ形式が未対応です（schema \(version)）。"
        case .invalidQualification:
            return "公式年度模試の資格識別子が一致しません。"
        case .missingYear(let year):
            return "令和\(year - 2018)年相当の公式採点データがありません。"
        case .invalidYear(let year, let reason):
            return "\(year)年の公式採点データが不正です（\(reason)）。"
        case .decodingFailed:
            return "公式年度模試の採点データを読み込めません。"
        }
    }
}

enum OfficialScoringRepository {
    static let resourceName = "official-scoring-canonical.v1"
    static let supportedYears = [2024, 2025]
    private static let expectedSubjectCounts: [String: Int] = [
        "憲法": 12,
        "行政法": 12,
        "民法": 15,
        "商法": 15,
        "民事訴訟法": 15,
        "刑法": 13,
        "刑事訴訟法": 13
    ]

    static func load(bundle: Bundle = Bundle(for: AppBundleToken.self)) throws -> OfficialScoringCanonical {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw OfficialScoringRepositoryError.resourceMissing
        }
        do {
            return try decodeAndValidate(data: Data(contentsOf: url))
        } catch let error as OfficialScoringRepositoryError {
            throw error
        } catch {
            throw OfficialScoringRepositoryError.decodingFailed
        }
    }

    static func decodeAndValidate(data: Data) throws -> OfficialScoringCanonical {
        let canonical: OfficialScoringCanonical
        do {
            canonical = try JSONDecoder().decode(OfficialScoringCanonical.self, from: data)
        } catch {
            throw OfficialScoringRepositoryError.decodingFailed
        }
        try validate(canonical)
        return canonical
    }

    static func validate(_ canonical: OfficialScoringCanonical) throws {
        guard canonical.schemaVersion == 1 else {
            throw OfficialScoringRepositoryError.invalidSchema(canonical.schemaVersion)
        }
        guard canonical.qualification == "司法試験予備試験・短答式" else {
            throw OfficialScoringRepositoryError.invalidQualification
        }

        for year in supportedYears {
            guard let yearData = canonical.years[String(year)] else {
                throw OfficialScoringRepositoryError.missingYear(year)
            }
            try validate(yearData, year: year)
        }
    }

    private static func validate(_ yearData: OfficialYearScoring, year: Int) throws {
        let legal = yearData.legal
        guard legal.questionCount == 95,
              legal.questions.count == 95,
              legal.maxPoints == 210,
              legal.questions.reduce(0, { $0 + $1.maxPoints }) == 210
        else {
            throw OfficialScoringRepositoryError.invalidYear(year, "法律科目の95問・210点契約")
        }

        guard legal.questions.allSatisfy({ $0.examYear == year && $0.isStructurallyValid }) else {
            throw OfficialScoringRepositoryError.invalidYear(year, "法律科目の問題構造")
        }
        guard Set(legal.questions.map(\.id)).count == legal.questions.count else {
            throw OfficialScoringRepositoryError.invalidYear(year, "問題ID重複")
        }

        let subjectCounts = Dictionary(grouping: legal.questions, by: \.subject).mapValues(\.count)
        guard subjectCounts == expectedSubjectCounts else {
            throw OfficialScoringRepositoryError.invalidYear(year, "科目別問題数")
        }

        let general = yearData.generalEducation
        let expectedOffered = year == 2024 ? 42 : 44
        guard general.offered == expectedOffered,
              general.select == 20,
              general.pointsPerSelectedQuestion == 3,
              general.maxPoints == 60,
              general.answerKey.count == expectedOffered,
              Set(general.answerKey.keys.compactMap(Int.init)) == Set(1...expectedOffered),
              general.answerKey.values.allSatisfy({ 1...8 ~= $0 }),
              URL(string: general.sourceURL)?.scheme == "https"
        else {
            throw OfficialScoringRepositoryError.invalidYear(year, "一般教養の出題・20問選択・60点契約")
        }

        guard yearData.totalMaxPoints == 270,
              yearData.officialPassScore > 0,
              yearData.officialPassScore <= 270
        else {
            throw OfficialScoringRepositoryError.invalidYear(year, "総得点・合格点")
        }
    }

    static func scoring(for year: Int, canonical: OfficialScoringCanonical) throws -> OfficialYearScoring {
        guard let data = canonical.years[String(year)] else {
            throw OfficialScoringRepositoryError.missingYear(year)
        }
        return data
    }
}
