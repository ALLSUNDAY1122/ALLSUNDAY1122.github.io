import fs from 'node:fs';
const read=p=>fs.readFileSync(p,'utf8');
const root='kanrieiyoushi-sprint';
const swift=read(`${root}/ios/App.swift`);
const js=read(`${root}/ios/native-storekit.js`);
const project=read(`${root}/ios/project.yml`);
const cm=read(`${root}/ios/codemagic-kanrieiyoushi.yml`);
const prep=read(`${root}/ios/prepare-ios.sh`);
const privacy=read(`${root}/privacy/index.html`);
const support=read(`${root}/support/index.html`);
const required=[
  [swift,'jp.allsunday1122.kanrieiyoushi.premium','IAP product'],
  [swift,'Product.products(for:','StoreKit product load'],
  [swift,'displayPrice','localized price'],
  [swift,'Transaction.currentEntitlements','entitlement'],
  [swift,'Transaction.updates','transaction updates'],
  [swift,'AppStore.sync()','explicit restore'],
  [swift,'case .pending','pending state'],
  [swift,'case .userCancelled','cancel state'],
  [swift,'revocationDate','revocation state'],
  [project,'jp.allsunday1122.kanrieiyoushi','bundle id'],
  [project,'管理栄養士 学びスプリント','display name'],
  [js,'無料版では第1回の各分野6問、合計60問','free scope'],
  [js,'全600問','premium scope'],
  [js,'購入を復元','restore UI'],
  [prep,'11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4','canonical icon id'],
  [cm,'submit_to_testflight: false','no auto Beta Review'],
  [cm,'submit_to_app_store: false','no auto App Store submit'],
  [privacy,'App内課金','privacy IAP disclosure'],
  [support,'購入を復元','support restore guidance']
];
let errors=[];for(const [text,token,label] of required)if(!text.includes(token))errors.push(`${label}: missing ${token}`);
for(const [name,text] of [['Swift',swift],['native JS',js]]){
  if(/[¥￥]\s*980|980\s*円/.test(text))errors.push(`${name}: hard-coded candidate price found`);
}
if(/submit_to_testflight:\s*true/.test(cm)||/submit_to_app_store:\s*true/.test(cm))errors.push('Codemagic automatic submission must remain disabled');
if(errors.length){console.error('FAIL: Apple preflight');errors.forEach(e=>console.error('-',e));process.exit(1);}
console.log('PASS: bundle/product IDs, StoreKit 2 lifecycle, displayPrice-only UI, 60/600 entitlement scope, privacy/support, and safe Codemagic publishing contract');
