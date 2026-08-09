import fs from 'node:fs';

const read = (p) => fs.readFileSync(p, 'utf8');
const must = (cond, msg) => { if (!cond) throw new Error(msg); };
const includes = (text, value, label=value) => must(text.includes(value), `missing: ${label}`);

const root = 'learning-sprint/shoshi';
const project = read(`${root}/ios/project.yml`);
const capabilityPatch = read(`${root}/ios/apply-xcode-capabilities.py`);
const swift = read(`${root}/ios/App.swift`);
const nativeStore = read(`${root}/ios/native-storekit.js`);
const prepareIos = read(`${root}/ios/prepare-ios.sh`);
const metadata = read(`${root}/app-store/APP_STORE_METADATA_JA.md`);
const packet = read(`${root}/app-store/APPLE_CONNECT_PACKET.md`);
const storekitPlan = read(`${root}/app-store/STOREKIT_TEST_PLAN.md`);
const review = read(`${root}/app-store/APP_REVIEW_NOTES_JA.md`);
const privacyHtml = read(`${root}/privacy/index.html`);
const supportHtml = read(`${root}/support/index.html`);
const privacyManifest = read(`${root}/ios/PrivacyInfo.xcprivacy`);
const questions = JSON.parse(read(`${root}/content-loop/questions.generated.json`));
const codemagic = read('codemagic.yaml');

const BUNDLE = 'jp.allsunday1122.shoshi';
const PRODUCT = 'jp.allsunday1122.shoshi.premium';
const VERSION = '1.0.0';
const SKU = 'shoshi-sprint-ios';
const SUPPORT = 'https://allsunday1122.github.io/learning-sprint/shoshi/support/';
const PRIVACY = 'https://allsunday1122.github.io/learning-sprint/shoshi/privacy/';
const ICON_SHA = 'c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506';

includes(project, `PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE}`, 'Xcode bundle id');
includes(project, `MARKETING_VERSION: ${VERSION}`, 'Xcode marketing version');
includes(project, 'UIInterfaceOrientationPortrait', 'portrait-only orientation');
includes(capabilityPatch, 'com.apple.InAppPurchase', 'generated-project In-App Purchase capability patch');
includes(capabilityPatch, 'enabled = 1;', 'enabled generated-project capability');

includes(swift, `static let productID = "${PRODUCT}"`, 'StoreKit product id');
includes(swift, 'Product.products(for:', 'StoreKit product loading');
includes(swift, 'displayPrice', 'localized StoreKit price');
includes(swift, 'Transaction.currentEntitlements', 'current entitlements');
includes(swift, 'Transaction.updates', 'transaction updates observer');
includes(swift, 'AppStore.sync()', 'restore purchases');
includes(swift, 'transaction.revocationDate == nil', 'revocation handling');
includes(swift, 'loadFileURL', 'local bundled web loading');
includes(swift, 'www.moj.go.jp', 'MOJ external whitelist');
includes(swift, 'laws.e-gov.go.jp', 'e-Gov external whitelist');

includes(nativeStore, 'shoshi-native-trial-completed-v1', 'one-sprint trial state');
includes(nativeStore, "'.subject-card,.mock-card,.weak-item,#startDaily,[data-goal=\"16\"]'", 'native premium gates');
includes(nativeStore, '価格を取得できません', 'StoreKit unavailable state');
includes(nativeStore, '購入承認待ち', 'pending purchase state');
includes(nativeStore, "send('restore')", 'restore bridge');
includes(nativeStore, SUPPORT, 'native support URL');
includes(nativeStore, PRIVACY, 'native privacy URL');
must(!/[¥￥]\s*\d/.test(nativeStore), 'native StoreKit UI must not hard-code a yen price');

includes(prepareIos, 'questions.generated.json', 'audited question bundle');
includes(prepareIos, 'native-storekit.js', 'native StoreKit UI bundle');
includes(prepareIos, ICON_SHA, 'canonical AppIcon SHA');
includes(prepareIos, 'drive.usercontent.google.com', 'canonical Drive icon source');
includes(prepareIos, "const DATA_URL = './questions.generated.json';", 'local question URL rewrite');
includes(prepareIos, "location.protocol !== 'file:'", 'service worker disabled for local native bundle');

must(Array.isArray(questions) && questions.length === 210, 'question count must remain 210');
must(new Set(questions.map(q => q.id)).size === 210, 'question IDs must remain unique');
const r7pm33 = questions.find(q => q.id === 'SHOSHI-R7-PM-33');
must(r7pm33 && r7pm33.scoring_status === 'all_correct' && r7pm33.official_answer_no == null, 'R7 PM33 all_correct contract broken');

for (const text of [metadata, packet]) {
  includes(text, BUNDLE, 'submission bundle id');
  includes(text, PRODUCT, 'submission IAP id');
  includes(text, SUPPORT, 'support URL');
  includes(text, PRIVACY, 'privacy URL');
}
includes(packet, `SKU: \`${SKU}\``, 'fixed SKU');
includes(packet, 'testFlightInternalTestingOnly: true', 'internal TestFlight export');
includes(packet, '`submit_to_testflight`: false', 'manual TestFlight upload gate');
includes(packet, '`submit_to_app_store`: false', 'manual App Review gate');
includes(metadata, 'Type: Non-Consumable', 'IAP type');
includes(metadata, 'コード・審査原稿には固定価格を書かない', 'no fixed price policy');
includes(storekitPlan, 'Sandbox購入成功', 'Sandbox purchase gate');
includes(storekitPlan, '購入を復元', 'Sandbox restore gate');
includes(storekitPlan, 'R7午後33', 'all-correct actual-device gate');
includes(review, '法務省の公式アプリではありません', 'review non-official disclaimer');
includes(privacyHtml, 'トラッキング', 'privacy tracking disclosure');
includes(privacyHtml, '分析SDK', 'privacy analytics disclosure');
includes(supportHtml, '令和7年度午後第33問', 'support correction disclosure');

includes(privacyManifest, '<key>NSPrivacyTracking</key>', 'Privacy Manifest tracking key');
includes(privacyManifest, '<false/>', 'Privacy Manifest tracking false');
includes(privacyManifest, '<key>NSPrivacyCollectedDataTypes</key>', 'Privacy Manifest collected data key');

const marker = '\n  shoshi-ios:';
must(codemagic.includes(marker), 'missing shoshi-ios workflow');
const block = codemagic.split(marker, 2)[1];
includes(block, 'app_store_connect: codemagic', 'Codemagic ASC integration');
includes(block, 'distribution_type: app_store', 'App Store distribution');
includes(block, `bundle_identifier: ${BUNDLE}`, 'Codemagic bundle id');
includes(block, `BUNDLE_ID: ${BUNDLE}`, 'Codemagic BUNDLE_ID');
includes(block, 'testFlightInternalTestingOnly', 'internal TestFlight only export');
includes(block, 'apply-xcode-capabilities.py', 'generated-project capability normalization');
includes(block, 'submit_to_testflight: false', 'no automatic TestFlight submission');
includes(block, 'submit_to_app_store: false', 'no automatic App Store review submission');
includes(block, 'CM_BUILD_NUMBER', 'CI build number');
must(!/submit_to_app_store:\s*true/.test(block), 'App Store auto-submit must stay disabled');

console.log('PASS: Shoshi Apple signing/TestFlight preflight contract is internally consistent.');
console.log(`Bundle=${BUNDLE}`);
console.log(`Product=${PRODUCT}`);
console.log(`Version=${VERSION}`);
console.log(`Questions=${questions.length}`);
console.log(`CanonicalIconSHA=${ICON_SHA}`);
