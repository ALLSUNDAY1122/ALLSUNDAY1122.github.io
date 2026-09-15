import SwiftUI

struct SettingsView: View { var body: some View { NavigationStack { List { Section("再生") { Text("バックグラウンド再生：有効"); Text("再生速度はレッスン画面で変更できます") } Section("データ") { Text("学習履歴はこの端末内に保存されます") } Section("サポート") { Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/english-listening-sprint/privacy.html")!); Link("サポート", destination: URL(string: "https://allsunday1122.github.io/english-listening-sprint/support.html")!) } }.scrollContentBackground(.hidden).background(SprintTheme.background).navigationTitle("Settings") } }
