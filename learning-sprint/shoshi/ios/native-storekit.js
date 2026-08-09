'use strict';
(() => {
  const TRIAL_KEY = 'shoshi-native-trial-completed-v1';
  const APP_STATE_KEY = 'shoshi-learning-sprint-v1';
  const bridge = window.webkit?.messageHandlers?.storeKit;
  const externalBridge = window.webkit?.messageHandlers?.openExternal;
  const store = { native: !!bridge, premium: !bridge, displayPrice: '', status: bridge ? 'unknown' : 'web' };
  let overlay;
  let settingsCard;

  function send(action) { if (bridge) bridge.postMessage({action}); }
  function openExternal(url) { if (externalBridge) externalBridge.postMessage({url}); else window.open(url, '_blank', 'noopener'); }
  function trialCompleted() { return localStorage.getItem(TRIAL_KEY) === '1'; }
  function dailyGoal() {
    try { const s=JSON.parse(localStorage.getItem(APP_STATE_KEY)||'{}'); const g=Number(s.dailyGoal||8); return Number.isFinite(g)?g:8; }
    catch (_) { return 8; }
  }
  function statusText() {
    if (store.premium) return 'プレミアム解放済み';
    if (store.displayPrice) return `買い切り ${store.displayPrice}`;
    if (store.status === 'product_unavailable' || store.status === 'error') return '価格を取得できません';
    if (store.status === 'pending') return '購入承認待ち';
    return '価格を取得中';
  }
  function canPurchase() { return store.native && !store.premium && !!store.displayPrice && !['product_unavailable','error','pending'].includes(store.status); }

  function injectStyles() {
    if (document.getElementById('nativePremiumStyles')) return;
    const style=document.createElement('style');
    style.id='nativePremiumStyles';
    style.textContent=`
      .native-paywall-backdrop{position:fixed;inset:0;z-index:1000;background:rgba(28,35,49,.48);display:grid;place-items:end center;padding:18px;padding-bottom:calc(18px + env(safe-area-inset-bottom));}
      .native-paywall-backdrop[hidden]{display:none!important}
      .native-paywall{width:min(100%,484px);background:#fffdf9;border:1px solid #ece4d6;border-radius:22px;padding:20px;box-shadow:0 18px 50px rgba(28,35,49,.22);color:#1c2331;}
      .native-paywall-head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px}.native-paywall-head h2{font-family:var(--serif);font-size:1.35rem;margin:4px 0 8px}.native-paywall-close{min-width:44px;min-height:44px;border:0;background:#eaeff6;border-radius:12px;color:#2f4a6d;font-weight:900;font-size:1.1rem}
      .native-paywall ul{margin:14px 0 18px;padding-left:1.3rem;line-height:1.75}.native-price{font-size:1.15rem;font-weight:900;color:#2f4a6d;margin:8px 0 14px}.native-buy,.native-restore{width:100%;min-height:50px;border-radius:14px;font:inherit;font-weight:900}.native-buy{border:0;background:#2f4a6d;color:white}.native-buy:disabled{opacity:.45}.native-restore{margin-top:9px;border:1px solid #d9d2c5;background:#fffdf9;color:#2f4a6d}.native-paywall-foot{font-size:.78rem;color:#8b8577;line-height:1.55;margin:12px 0 0}.native-links{display:flex;gap:14px;flex-wrap:wrap;margin-top:12px}.native-link{border:0;background:transparent;padding:0;color:#2f4a6d;text-decoration:underline;font:inherit;font-size:.78rem}
      .native-premium-card{margin-top:14px}.native-premium-card .native-status{font-weight:900;color:#2f4a6d;margin:.35rem 0 .8rem}.native-premium-card button{min-height:46px}.native-lock-note{display:block;margin-top:5px;font-size:.72rem;color:#8b8577;font-weight:700}
    `;
    document.head.appendChild(style);
  }

  function ensurePaywall() {
    if (overlay) return overlay;
    overlay=document.createElement('div'); overlay.className='native-paywall-backdrop'; overlay.hidden=true;
    overlay.innerHTML=`<section class="native-paywall" role="dialog" aria-modal="true" aria-labelledby="nativePaywallTitle"><div class="native-paywall-head"><div><p class="kicker">PREMIUM</p><h2 id="nativePaywallTitle">210問をすべて解放</h2></div><button class="native-paywall-close" type="button" aria-label="閉じる">×</button></div><p class="muted">無料体験は「今日のスプリント」1回、最大8問です。買い切りで次を解放します。</p><ul><li>令和5〜7年度の公式択一210問</li><li>年度 × 11科目の指定演習</li><li>午前・午後6枠の模試</li><li>苦手問題の個別復習</li></ul><div class="native-price" data-native-price>価格を取得中</div><button class="native-buy" data-native-purchase type="button" disabled>価格を取得しています</button><button class="native-restore" data-native-restore type="button">購入を復元</button><p class="native-paywall-foot">価格はApp Storeから取得します。このアプリは法務省の公式アプリではありません。</p><div class="native-links"><button class="native-link" data-native-privacy type="button">プライバシーポリシー</button><button class="native-link" data-native-support type="button">サポート</button></div></section>`;
    document.body.appendChild(overlay);
    overlay.querySelector('.native-paywall-close').addEventListener('click',hidePaywall);
    overlay.addEventListener('click',e=>{if(e.target===overlay)hidePaywall();});
    overlay.querySelector('[data-native-purchase]').addEventListener('click',()=>send('purchase'));
    overlay.querySelector('[data-native-restore]').addEventListener('click',()=>send('restore'));
    overlay.querySelector('[data-native-privacy]').addEventListener('click',()=>openExternal('https://allsunday1122.github.io/learning-sprint/shoshi/privacy/'));
    overlay.querySelector('[data-native-support]').addEventListener('click',()=>openExternal('https://allsunday1122.github.io/learning-sprint/shoshi/support/'));
    return overlay;
  }
  function showPaywall(){if(!store.native||store.premium)return;ensurePaywall().hidden=false;applyStoreUI();send('refresh');}
  function hidePaywall(){if(overlay)overlay.hidden=true;}

  function ensureSettingsCard(){
    if(!store.native||settingsCard)return;
    const view=document.getElementById('settingsView');if(!view)return;
    settingsCard=document.createElement('article');settingsCard.className='paper-card settings-card native-premium-card';
    settingsCard.innerHTML=`<label>プレミアム</label><p class="native-status">価格を取得中</p><p class="muted">無料体験後、買い切りで210問・科目別・模試・苦手復習を解放します。</p><div class="stack-actions"><button class="secondary-button" data-settings-buy type="button">プレミアムを確認</button><button class="secondary-button" data-settings-restore type="button">購入を復元</button></div>`;
    const sourceNote=view.querySelector('.source-note');view.insertBefore(settingsCard,sourceNote||null);
    settingsCard.querySelector('[data-settings-buy]').addEventListener('click',showPaywall);
    settingsCard.querySelector('[data-settings-restore]').addEventListener('click',()=>send('restore'));
  }

  function applyStoreUI(){
    if(!store.native)return;ensureSettingsCard();const price=statusText();
    document.querySelectorAll('[data-native-price]').forEach(el=>{el.textContent=price;});
    document.querySelectorAll('[data-native-purchase]').forEach(btn=>{btn.disabled=!canPurchase();btn.textContent=store.premium?'解放済み':canPurchase()?`${store.displayPrice}で解放`:store.status==='product_unavailable'||store.status==='error'?'価格を取得できません':store.status==='pending'?'購入承認待ち':'価格を取得しています';});
    if(settingsCard){settingsCard.querySelector('.native-status').textContent=price;settingsCard.querySelector('[data-settings-buy]').textContent=store.premium?'プレミアム解放済み':'プレミアムを確認';settingsCard.querySelector('[data-settings-buy]').disabled=store.premium;}
    if(store.premium)hidePaywall();
  }

  window.__nativeStoreKitUpdate=payload=>{if(!payload||typeof payload!=='object')return;store.native=true;store.premium=!!payload.premium;store.displayPrice=typeof payload.displayPrice==='string'?payload.displayPrice:'';store.status=payload.status||'known';applyStoreUI();};
  function gatedTarget(target){return target.closest('.subject-card,.mock-card,.weak-item,#startDaily,[data-goal="16"]');}
  document.addEventListener('click',event=>{if(!store.native||store.premium)return;const target=gatedTarget(event.target);if(!target)return;const premiumOnly=target.matches('.subject-card,.mock-card,.weak-item,[data-goal="16"]');const dailyLocked=target.id==='startDaily'&&(trialCompleted()||dailyGoal()>8);if(!premiumOnly&&!dailyLocked)return;event.preventDefault();event.stopImmediatePropagation();showPaywall();},true);

  function watchTrialCompletion(){const result=document.getElementById('resultView');if(!result||!store.native)return;const observer=new MutationObserver(()=>{if(!store.premium&&result.classList.contains('active'))localStorage.setItem(TRIAL_KEY,'1');});observer.observe(result,{attributes:true,attributeFilter:['class']});}
  document.addEventListener('DOMContentLoaded',()=>{if(!store.native)return;injectStyles();ensurePaywall();ensureSettingsCard();watchTrialCompletion();const offline=document.getElementById('offlineStatus');if(offline)offline.textContent='210問と画面をアプリ本体に同梱しています。通信なしでも学習できます。';applyStoreUI();send('refresh');});
})();
