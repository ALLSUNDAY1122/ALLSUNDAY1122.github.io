import SwiftUI
import WebKit
import StoreKit

@main
struct FP3ManabiSprintApp: App {
    @StateObject private var store = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            WebAppView(store: store)
                .ignoresSafeArea(.keyboard)
        }
    }
}

@MainActor
final class StoreKitManager: ObservableObject {
    static let productID = "jp.allsunday1122.fp3manabisprint.premium"

    @Published private(set) var isPremium = false
    @Published private(set) var displayPrice = ""
    @Published private(set) var status = "unknown"

    private var product: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var productLoadFailed = false
        if product == nil {
            do {
                product = try await Product.products(for: [Self.productID]).first
                displayPrice = product?.displayPrice ?? ""
            } catch {
                productLoadFailed = true
            }
        }

        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
        if productLoadFailed { status = "error" }
        else { status = product == nil ? "product_unavailable" : "known" }
    }

    func purchase() async {
        if product == nil { await refresh() }
        guard let product else { status = "product_unavailable"; return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                }
            case .pending: status = "pending"
            case .userCancelled: status = "cancelled"
            @unknown default: status = "unknown"
            }
        } catch { status = "error" }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch { status = "error" }
    }

    func payload() -> [String: Any] {
        ["native": true, "premium": isPremium, "displayPrice": displayPrice, "status": status]
    }
}

struct WebAppView: UIViewRepresentable {
    @ObservedObject var store: StoreKitManager

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "storeKit")
        controller.addUserScript(WKUserScript(
            source: Self.storeKitBridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 253/255, green: 246/255, blue: 239/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true),
              let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            webView.loadHTMLString(Self.missingBundleHTML, baseURL: nil)
            return webView
        }
        webView.loadFileURL(url, allowingReadAccessTo: webRoot)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = store
        context.coordinator.pushStoreKitState()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "storeKit")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var store: StoreKitManager
        weak var webView: WKWebView?

        init(store: StoreKitManager) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await store.refresh()
                pushStoreKitState()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "storeKit",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }
            Task { @MainActor in
                switch action {
                case "purchase": await store.purchase()
                case "restore": await store.restore()
                default: await store.refresh()
                }
                pushStoreKitState()
            }
        }

        @MainActor
        func pushStoreKitState() {
            guard let webView,
                  JSONSerialization.isValidJSONObject(store.payload()),
                  let data = try? JSONSerialization.data(withJSONObject: store.payload()),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.__nativeStoreKitUpdate && window.__nativeStoreKitUpdate(\(json));")
        }
    }

    private static let storeKitBridgeScript = #"""
    (() => {
      if (window.__fp3NativeBridgeInstalled) return;
      window.__fp3NativeBridgeInstalled = true;
      const state = { native:true, premium:false, displayPrice:'', status:'unknown' };
      const post = action => {
        const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.storeKit;
        if (h) h.postMessage({action});
      };
      const premiumTarget = el => {
        if (!el) return false;
        if (el.id === 'startWeak') return true;
        if (el.closest && el.closest('#domains')) return true;
        if (el.closest && el.closest('#years')) {
          const t = (el.textContent || '').replace(/\s/g,'');
          return t.includes('2024') || t.includes('2025');
        }
        return false;
      };
      const ensureStyle = () => {
        if (document.getElementById('fp3-native-paywall-style')) return;
        const s=document.createElement('style'); s.id='fp3-native-paywall-style';
        s.textContent=`.fp3-premium-lock{position:relative}.fp3-premium-lock:after{content:'Premium';position:absolute;right:9px;top:8px;background:#fdeee2;color:#a8481c;border-radius:999px;padding:3px 7px;font-size:10px;font-weight:900}.fp3-paywall-backdrop{position:fixed;inset:0;z-index:9999;background:rgba(35,31,26,.38);display:grid;place-items:end center;padding:16px}.fp3-paywall-backdrop[hidden]{display:none}.fp3-paywall{width:min(100%,520px);background:#fff;border-radius:22px;padding:20px;box-shadow:0 12px 40px rgba(0,0,0,.22);font-family:-apple-system,BlinkMacSystemFont,'Hiragino Sans','Yu Gothic',sans-serif}.fp3-paywall h2{margin:0 0 7px;font-size:1.25rem}.fp3-paywall p,.fp3-paywall li{font-size:.84rem;line-height:1.55}.fp3-paywall ul{padding-left:20px}.fp3-paywall button{width:100%;min-height:50px;border-radius:14px;font-weight:900;margin-top:8px}.fp3-buy{border:0;background:#ee7d3f;color:white}.fp3-restore,.fp3-close{border:1px solid #f0e4d6;background:white;color:#231f1a}.fp3-store-status{color:#726b60;font-size:.75rem;text-align:center;margin-top:8px}.fp3-scope-note{margin-top:10px;padding:10px 12px;border-radius:12px;background:#fff8f2;color:#726b60;font-size:.75rem;line-height:1.55}`;
        document.head.appendChild(s);
      };
      const ensurePaywall = () => {
        ensureStyle();
        let b=document.getElementById('fp3-native-paywall'); if(b) return b;
        b=document.createElement('div'); b.id='fp3-native-paywall'; b.className='fp3-paywall-backdrop'; b.hidden=true;
        b.innerHTML=`<div class="fp3-paywall" role="dialog" aria-modal="true" aria-label="Premium"><h2>Premiumで学習範囲を広げる</h2><p>無料版は2026年度60問を中心に学習できます。Premiumは買い切りで、現行基準へ補正した全178問を活用できます。</p><ul><li>2024・2025年度を含む全178問</li><li>6分野から選ぶ分野別演習</li><li>苦手復習と3連続正解での卒業</li></ul><button class="fp3-buy" data-native-purchase disabled>価格を取得中…</button><button class="fp3-restore" data-native-restore>購入を復元</button><button class="fp3-close">今はしない</button><div class="fp3-store-status" data-native-price></div></div>`;
        document.body.appendChild(b);
        b.querySelector('[data-native-purchase]').addEventListener('click',()=>post('purchase'));
        b.querySelector('[data-native-restore]').addEventListener('click',()=>post('restore'));
        b.querySelector('.fp3-close').addEventListener('click',()=>{b.hidden=true});
        return b;
      };
      const showPaywall = () => { const b=ensurePaywall(); if(!state.premium) b.hidden=false; };
      const decorate = () => {
        ensurePaywall();
        document.querySelectorAll('#domains button,#years button,#startWeak').forEach(el=>{
          const locked = !state.premium && premiumTarget(el);
          el.classList.toggle('fp3-premium-lock',locked);
          el.setAttribute('aria-label', locked ? `${el.textContent.trim()} Premium` : el.textContent.trim());
        });
        const title=document.querySelector('#home .title'); if(title && title.textContent.trim()==='FP3級') title.textContent='FP3級 学科';
        const top=document.querySelector('#home .top');
        if(top && !document.getElementById('fp3-scope-note')){
          const n=document.createElement('div'); n.id='fp3-scope-note'; n.className='fp3-scope-note';
          n.textContent='学科CBT対策｜2026-04-01基準へ補正。公式認定アプリではありません。'; top.appendChild(n);
        }
        const settings=document.querySelector('#settings .section .card');
        if(settings && !document.getElementById('fp3-source-note')){
          const n=document.createElement('div'); n.id='fp3-source-note'; n.className='fp3-scope-note';
          n.textContent='出典：日本FP協会・金融財政事情研究会の公開試験問題を参照。学習用に表現・解説・法令基準を加工しています。'; settings.appendChild(n);
        }
        const buy=document.querySelector('[data-native-purchase]'), price=document.querySelector('[data-native-price]');
        if(buy){ const ready=state.status==='known' && !!state.displayPrice; buy.disabled=!ready; buy.textContent=ready?`${state.displayPrice}でPremiumを購入`:(state.status==='pending'?'購入承認待ち':'価格を取得中…'); }
        if(price) price.textContent=state.premium?'Premium購入済み':(state.status==='error'?'App Storeへ接続できません':state.displayPrice?`買い切り ${state.displayPrice}`:'');
        const backdrop=document.getElementById('fp3-native-paywall'); if(state.premium && backdrop) backdrop.hidden=true;
      };
      document.addEventListener('click',e=>{
        const el=e.target && e.target.closest ? e.target.closest('button') : null;
        if(!state.premium && premiumTarget(el)){ e.preventDefault(); e.stopImmediatePropagation(); showPaywall(); }
      },true);
      const originalBalanced12 = window.balanced12;
      window.balanced12 = function(){
        if(state.premium && typeof originalBalanced12==='function') return originalBalanced12();
        const a=(typeof activeBank==='function'?activeBank():[]).filter(q=>String(q.year)==='2026');
        let out=[]; (window.DOMAINS || (typeof DOMAINS!=='undefined'?DOMAINS:[])).forEach(d=>out.push(...sample(a.filter(q=>q.domain===d),2)));
        return sample(out,12);
      };
      window.__nativeStoreKitUpdate = payload => {
        if(payload && typeof payload==='object') Object.assign(state,payload);
        decorate();
      };
      new MutationObserver(decorate).observe(document.documentElement,{childList:true,subtree:true});
      decorate(); post('refresh');
    })();
    """#

    private static let missingBundleHTML = """
    <!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>
    <body style='font-family:-apple-system;padding:32px;background:#fdf6ef;color:#231f1a'>
    <h2>教材データを読み込めませんでした</h2><p>アプリを再インストールしてください。</p></body>
    """
}
