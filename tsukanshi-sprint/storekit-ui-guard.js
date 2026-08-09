'use strict';
(function(){
  const state={native:false,status:'unknown',displayPrice:''};
  const hasNativeStoreKit=()=>!!(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.storeKit);
  state.native=hasNativeStoreKit();

  const original=window.__nativeStoreKitUpdate;
  if(typeof original==='function'){
    window.__nativeStoreKitUpdate=function(payload){
      if(payload&&typeof payload==='object'){
        state.native=true;
        state.status=payload.status||'known';
        state.displayPrice=typeof payload.displayPrice==='string'?payload.displayPrice:'';
      }
      original(payload);
      queueMicrotask(apply);
    };
  }

  function priceLabel(){
    if(!state.native)return 'App Store版で価格を表示';
    if(state.displayPrice)return state.displayPrice;
    if(state.status==='product_unavailable'||state.status==='error')return '価格を取得できません';
    return '価格を取得中';
  }

  function purchasable(){
    return state.native&&!!state.displayPrice&&!['product_unavailable','error'].includes(state.status);
  }

  function apply(){
    const canBuy=purchasable();
    document.querySelectorAll('.pay-price').forEach(el=>{el.textContent=priceLabel()});
    document.querySelectorAll('[data-purchase]').forEach(btn=>{
      btn.disabled=!canBuy;
      btn.textContent=!state.native?'App Store版で利用できます':canBuy?'プレミアムを解放':'価格を取得しています';
    });
    document.querySelectorAll('[data-buy]').forEach(btn=>{
      if(String(btn.textContent||'').includes('購入状態を確認'))return;
      btn.disabled=!canBuy;
      btn.textContent=!state.native?'App Store版で利用できます':canBuy?`${state.displayPrice}で解放`:'価格を取得しています';
    });
    document.querySelectorAll('[data-restore]').forEach(btn=>{
      btn.disabled=!state.native;
    });
  }

  const observer=new MutationObserver(apply);
  observer.observe(document.body,{childList:true,subtree:true});
  apply();
})();
