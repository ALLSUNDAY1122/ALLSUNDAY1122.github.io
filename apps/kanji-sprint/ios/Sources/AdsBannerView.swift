import SwiftUI
import UIKit
import GoogleMobileAds

/// AdMob バナーのラッパ。本番ユニットID（kanji_banner）を使用する。
/// 子ども向け設定は KanjiStudyApp の requestConfiguration で行い、
/// ここではリクエストに非パーソナライズ（npa=1）を付ける。
struct AdsBannerView: UIViewRepresentable {
    static let unitID = "ca-app-pub-3070038454022343/7484363955"

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = Self.unitID
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
