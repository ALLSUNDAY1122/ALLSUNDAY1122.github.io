const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const paywall=fs.readFileSync('app/paywall.tsx','utf8');
const mapper=fs.readFileSync('src/services/purchaseMessages.ts','utf8');
const config=fs.readFileSync('app.config.ts','utf8');
const ocr=fs.readFileSync('src/services/geminiOcr.ts','utf8');
const usage=fs.readFileSync('src/services/cloudUsage.ts','utf8');

test('subscribed 100 and 50 plans resolved from verified entitlement',()=>{
  assert.match(paywall,/entitlement\.limit===100/);
  assert.match(paywall,/entitlement\.limit===50/);
  assert.match(paywall,/await verifyPurchase\(jws\)/);
});
test('own plan is marked and cannot be bought again',()=>{
  assert.match(paywall,/current\?'ご利用中'/);
  assert.match(paywall,/disabled=\{current\|\|busy/);
  assert.match(paywall,/if\(entitlement\.productId===productId\)/);
});
test('plan change uses StoreKit subscription management with fallback',()=>{
  assert.match(paywall,/showManageSubscriptionsIOS\(\)/);
  assert.match(paywall,/https:\/\/apps\.apple\.com\/account\/subscriptions/);
  assert.match(paywall,/alternative\?manage\(\):purchase\(id\)/);
  assert.match(paywall,/プラン変更はiPhone/);
});
test('errors localized and cancelled purchase silenced',()=>{
  assert.match(mapper,/already owned/);
  assert.match(mapper,/network/);
  assert.match(mapper,/isCancelledPurchase/);
  assert.match(paywall,/if\(isCancelledPurchase\(error\)\)/);
  assert.doesNotMatch(paywall,/setStatus\(error\.message/);
  assert.doesNotMatch(paywall,/setStatus\(String\(error\)\)/);
});
test('subscription unknown disables purchasing and can be retried',()=>{
  assert.match(paywall,/entitlement\.kind==='error'/);
  assert.match(paywall,/加入状況を再確認/);
  assert.match(paywall,/現在サブスクリプションをご利用中/);
});
test('Build19 changes no Build17 OCR transport and Build18 usage presentation',()=>{
  assert.match(ocr,/new XMLHttpRequest\(\)/);
  assert.match(ocr,/for\(let attempt=1;attempt<=3;attempt\+\+\)/);
  assert.match(usage,/useSyncExternalStore/);
  assert.match(config,/buildNumber: '(?:19|20)'/);
});
