import SwiftUI
import UIKit
import GoogleMobileAds

/// AdMob バナーのラッパ。Build 1 は Google のテスト用ユニットIDを使う。
/// 本番ユニットIDは AdMob アカウント開設後に差し替える（README 参照）。
/// 子ども向け設定は KanjiStudyApp の requestConfiguration で行い、
/// ここではリクエストに非パーソナライズ（npa=1）を付ける。
struct AdsBannerView: UIViewRepresentable {
    static let testUnitID = "ca-app-pub-3940256099942544/2934735716"

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = Self.testUnitID
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            banner.rootViewController = root
        }
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
