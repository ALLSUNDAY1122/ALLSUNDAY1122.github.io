import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: QuestionStore
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @State private var showSettings = false
    @State private var showPremium = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    if !premium.isPremium {
                        freeTrialCard
                        premiumCard
                    }
                    weakCard
                    sessionList
                    if !records.state.history.isEmpty {
                        historyCard
                    }
                }
                .padding(16)
            }
            .background(Palette.paper)
            .navigationTitle("保健師｜学びスプリント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Palette.teal)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPremium) { PremiumView() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("学習の記録")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.teal)
            HStack(spacing: 18) {
                statItem(value: "\(records.studiedCount)", label: "学習済み / 546問")
                statItem(value: "\(records.totalAnswered)", label: "総回答数")
                statItem(value: records.totalAnswered > 0 ? "\(records.accuracy)%" : "—", label: "正答率")
                statItem(value: "\(records.todayAnswered)", label: "今日の回答")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.sub)
        }
    }

    private var freeTrialCard: some View {
        NavigationLink {
            QuizView(title: "無料で試す（第112回 30問）", questions: store.freeQuestions)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("無料で試す")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("最新・第112回の30問（午前15問＋午後15問）")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.sub)
            }
            .padding(14)
            .background(Palette.tealSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.teal.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }

    private var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text("全546問を解放する")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("第108〜112回 全5回分・買い切り（月額なし）")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(14)
            .background(Palette.teal, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var weakCard: some View {
        Group {
            if records.weakCount == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Palette.good)
                    Text("復習中の問題はありません")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                }
                .padding(14)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
            } else {
                let weak = records.weakQuestions()
                let playable = premium.isPremium ? weak : weak.filter(QuestionStore.isFree)
                Group {
                    if playable.isEmpty {
                        Button { showPremium = true } label: { weakRow }
                    } else {
                        NavigationLink {
                            QuizView(title: "苦手復習（\(playable.count)問）", questions: playable)
                        } label: { weakRow }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weakRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("苦手復習")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("復習中の問題が \(records.weakCount) 問あります（3回連続正解で卒業）")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Palette.sub)
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("回ごとに解く")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
            ForEach(store.sessionsDescending, id: \.self) { session in
                VStack(spacing: 8) {
                    ForEach(["AM", "PM"], id: \.self) { period in
                        sessionRow(session: session, period: period)
                    }
                }
            }
        }
    }

    private func sessionRow(session: Int, period: String) -> some View {
        let list = store.questions(session: session, period: period)
        let stats = records.stats(for: list)
        let label = period == "AM" ? "午前" : "午後"
        let row = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("第\(session)回 \(label)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(stats.attempts > 0
                     ? "回答済み \(stats.studied)/\(stats.total)問 ・ 正答率 \(stats.accuracy)%\(stats.weak > 0 ? " ・ 復習中 \(stats.weak)問" : "")"
                     : "全\(stats.total)問 ・ 未学習")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
            }
            Spacer()
            if premium.isPremium {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.sub)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
        return Group {
            if premium.isPremium {
                NavigationLink {
                    QuizView(title: "第\(session)回 \(label)", questions: list)
                } label: { row }
            } else {
                Button { showPremium = true } label: { row }
            }
        }
        .buttonStyle(.plain)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近の学習")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.teal)
            ForEach(records.state.history.prefix(5)) { entry in
                HStack {
                    Text(entry.title)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.score)/\(entry.total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(entry.date, format: .dateTime.month().day())
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }
}
