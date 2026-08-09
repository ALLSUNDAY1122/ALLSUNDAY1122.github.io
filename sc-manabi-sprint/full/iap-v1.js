// In-App Purchase / premium gating v1.1
// Native iOS: free = IPA official 75 questions. Premium = +250 original questions + domain practice.
// Web/Safari review build: all content remains available for product review and debugging.
const PREMIUM_PRODUCT_ID='jp.allsunday1122.scmanabisprint.premium';
const PREMIUM_CACHE_KEY='sc-premium-entitlement-v1';
const IAP={native:false,ready:false,supported:false,entitled:false,product:null,error:'',busy:false};

function isNativeApp(){
  try{return !!(window.Capacitor&&typeof window.Capacitor.isNativePlatform==='function'&&window.Capacitor.isNativePlatform())}catch(_){return false}
}
function nativePurchases(){return window.Capacitor?.Plugins?.NativePurchases||null}
function cachedPremium(){try{return localStorage.getItem(PREMIUM_CACHE_KEY)==='1'}catch(_){return false}}
function cachePremium(v){try{localStorage.setItem(PREMIUM_CACHE_KEY,v?'1':'0')}catch(_){}}
function hasPremium(){return !IAP.native||IAP.entitled}
function accessPool(){return hasPremium()?Q:Q.filter(q=>q.official)}
function accessIdSet(){return new Set(accessPool().map(q=>q.id))}
function premiumPrice(){return IAP.product?.priceString||''}
function purchaseErrorText(e){
  const s=String(e?.message||e||'');
  if(/cancel|cancelled|canceled/i.test(s))return '購入はキャンセルされました。';
  if(/pending|deferred/i.test(s))return '購入は保留中です。承認後に自動反映されます。';
  return '購入処理を完了できませんでした。時間をおいて再度お試しください。';
}

async function refreshPremiumEntitlement(){
  if(!IAP.native){IAP.entitled=true;IAP.ready=true;return true}
  const np=nativePurchases();
  if(!np)throw new Error('StoreKit bridge unavailable');
  const {purchases=[]}=await np.getPurchases({productType:'inapp',onlyCurrentEntitlements:true});
  IAP.entitled=purchases.some(p=>p.productIdentifier===PREMIUM_PRODUCT_ID);
  cachePremium(IAP.entitled);
  return IAP.entitled;
}

async function initPremium(){
  IAP.native=isNativeApp();
  if(!IAP.native){IAP.ready=true;IAP.supported=false;IAP.entitled=true;render();return}
  // Keep a previously StoreKit-verified entitlement available while offline.
  IAP.entitled=cachedPremium();
  try{
    const np=nativePurchases();
    if(!np)throw new Error('NativePurchases unavailable');
    const support=await np.isBillingSupported();
    IAP.supported=!!support?.isBillingSupported;
    if(!IAP.supported)throw new Error('Billing unavailable');
    try{
      const {product}=await np.getProduct({productIdentifier:PREMIUM_PRODUCT_ID,productType:'inapp'});
      IAP.product=product||null;
    }catch(e){
      IAP.error='商品情報を取得できません。';
    }
    await refreshPremiumEntitlement();
    if(typeof np.addListener==='function'){
      np.addListener('transactionUpdated',async()=>{try{await refreshPremiumEntitlement();render()}catch(_){}}).catch?.(()=>{});
    }
  }catch(e){
    // A temporary StoreKit/network failure must not revoke a purchase verified previously.
    IAP.error=IAP.entitled?'購入済み状態でオフライン利用中です。':purchaseErrorText(e);
  }finally{
    IAP.ready=true;
    render();
  }
}

async function buyPremium(){
  if(!IAP.native){alert('Safari確認版ではプレミアム機能を開放済みです。実際の購入はiOSアプリで行います。');return}
  if(IAP.busy||!IAP.supported)return;
  const np=nativePurchases();if(!np)return;
  IAP.busy=true;IAP.error='';render();
  try{
    if(!IAP.product){
      const {product}=await np.getProduct({productIdentifier:PREMIUM_PRODUCT_ID,productType:'inapp'});
      IAP.product=product||null;
    }
    const tx=await np.purchaseProduct({productIdentifier:PREMIUM_PRODUCT_ID,productType:'inapp',quantity:1});
    if(tx?.productIdentifier===PREMIUM_PRODUCT_ID){IAP.entitled=true;cachePremium(true)}
    await refreshPremiumEntitlement();
    alert('プレミアムを解放しました。');
  }catch(e){
    IAP.error=purchaseErrorText(e);
  }finally{IAP.busy=false;render()}
}

async function restorePremium(){
  if(!IAP.native){alert('Safari確認版では復元操作は不要です。');return}
  if(IAP.busy)return;
  const np=nativePurchases();if(!np)return;
  IAP.busy=true;IAP.error='';render();
  try{
    await np.restorePurchases();
    const ok=await refreshPremiumEntitlement();
    alert(ok?'購入を復元しました。':'復元できる購入は見つかりませんでした。');
  }catch(e){IAP.error=purchaseErrorText(e)}finally{IAP.busy=false;render()}
}

// Override the source pool used by daily sprint. Free users still get all 75 official questions.
pick=function(n){
  const pool=accessPool(),allowed=new Set(pool.map(q=>q.id));
  const w=sh(Object.keys(S.weak||{}).filter(id=>BYID[id]&&allowed.has(id))).slice(0,Math.ceil(n/2));
  const used=new Set(w),r=sh(pool.map(q=>q.id).filter(id=>!used.has(id)));
  return [...w,...r].slice(0,n);
};

weak=function(){
  const allowed=accessIdSet();
  const ids=sh(Object.keys(S.weak||{}).filter(id=>BYID[id]&&allowed.has(id))).slice(0,16);
  if(!ids.length){alert(hasPremium()?'復習対象の苦手問題はありません。':'無料版で復習できる公開過去問の苦手問題はありません。');return}
  begin('weak',ids);
};

countdown=function(){
  if(!S.examDate||!Q.length)return'';
  const pool=accessPool(),allowed=new Set(pool.map(q=>q.id));
  let d=new Date(S.examDate+'T00:00:00'),t=new Date();t.setHours(0,0,0,0);
  let days=Math.ceil((d-t)/86400000),done=Object.keys(S.done||{}).filter(id=>allowed.has(id)).length;
  let pace=days>0?Math.ceil((pool.length-done)/days):pool.length-done;
  return `<div class="card"><div class="row"><div><div class="muted">試験日まで</div><h2>${Math.max(0,days)}日</h2></div><div style="text-align:right"><div class="muted">${hasPremium()?'全325問':'無料75問'} 1周の目安</div><b>1日 ${Math.max(0,pace)}問</b></div></div></div>`;
};

function premiumPaywall(){
  if(!IAP.native){
    return `<div class="notice"><b>Safari確認版</b><br>Web確認では325問をすべて開放しています。App Store版では公開過去問75問が無料、独自250問＋分野別演習が買い切りプレミアムです。</div>`;
  }
  if(IAP.entitled){
    return `<div class="card"><div class="row"><div><div class="kicker">PREMIUM</div><h3>プレミアム解放済み</h3></div><span class="badge original">325問</span></div><p class="muted">公開過去問75問＋独自250問、全325問スプリントと分野別演習を利用できます。</p>${IAP.error?`<p class="muted" role="status">${esc(IAP.error)}</p>`:''}<button class="btn alt" onclick="restorePremium()">購入を復元</button></div>`;
  }
  const price=premiumPrice();
  const title=IAP.product?.title||'プレミアム問題パック';
  const label=IAP.busy?'処理中…':price?`${price}で買い切り解放`:'価格を取得中…';
  const disabled=(!IAP.ready||!IAP.supported||!price||IAP.busy)?'disabled':'';
  return `<div class="card"><div class="kicker">PREMIUM｜買い切り</div><h2>${esc(title)}</h2><p>無料版ではIPA公開過去問75問、8問スプリント、3回分模試、苦手復習を利用できます。</p><div class="feedback"><b>プレミアムで解放</b><br>独自問題250問／全325問スプリント／分野別演習</div><button class="btn" ${disabled} onclick="buyPremium()">${esc(label)}</button><button class="btn alt" ${IAP.busy?'disabled':''} onclick="restorePremium()">購入を復元</button>${IAP.error?`<p class="muted" role="status">${esc(IAP.error)}</p>`:''}<p class="muted">一度購入すると期限なく利用できます。商品名と価格はApp Storeから取得して表示します。</p></div>`;
}

function premiumTopicPractice(){
  if(!hasPremium())return premiumPaywall();
  const counts={};for(const q of Q)counts[q.t]=(counts[q.t]||0)+1;
  const topics=Object.entries(counts).sort((a,b)=>b[1]-a[1]).slice(0,8);
  return `<div class="card"><div class="kicker">PREMIUM</div><h2>分野から解く</h2><p class="muted">分野を選んで最大16問を集中演習します。</p>${topics.map(([t,n])=>`<button class="choice" onclick="domainPractice(decodeURIComponent('${encodeURIComponent(t)}'))"><b>${esc(t)}</b><br><span class="muted">${n}問</span></button>`).join('')}</div>`;
}

function domainPractice(topic){
  if(!hasPremium()){alert('分野別演習はプレミアム機能です。');nav('settings');return}
  const ids=sh(Q.filter(q=>q.t===topic).map(q=>q.id)).slice(0,16);
  if(!ids.length)return;
  S.active={mode:'domain',topic,ids,round:0,part:0,i:0,correct:0,answers:[],revealed:false};
  S.tab='quiz';save();render();
}

const _homeIapBase=home;
home=function(){
  const html=_homeIapBase();
  const pool=accessPool(),allowed=new Set(pool.map(q=>q.id));
  const done=Object.keys(S.done||{}).filter(id=>allowed.has(id)).length;
  const suffix=`<div class="card"><div class="row"><div><div class="muted">現在の学習範囲</div><h3>${hasPremium()?'全325問':'無料75問'}</h3></div><span class="badge ${hasPremium()?'original':'official'}">${hasPremium()?'PREMIUM':'FREE'}</span></div><p class="muted">学習済み ${done}/${pool.length}問</p></div>${hasPremium()?premiumTopicPractice():premiumPaywall()}`;
  return html+suffix;
};

const _resultIapBase=result;
result=function(){
  const r=S.lastResult;
  if(r?.mode==='domain'){
    const p=Math.round(r.correct/r.total*100);
    return `<header><div><div class="kicker">学習結果</div><div class="title">分野別演習</div></div></header><div class="card" style="text-align:center"><div class="ring" style="--p:${p}%;margin:0 auto 16px"><b>${p}%</b></div><h2>${r.correct} / ${r.total}問 正解</h2><p class="muted">誤答は苦手へ戻ります。</p></div><button class="btn alt" onclick="nav('home')">ホームへ</button>`;
  }
  return _resultIapBase();
};

const _settingsIapBase=settings;
settings=function(){return _settingsIapBase()+premiumPaywall()};

// Initialize after the Capacitor bridge is available. The current Safari review URL remains fully unlocked.
setTimeout(initPremium,0);
