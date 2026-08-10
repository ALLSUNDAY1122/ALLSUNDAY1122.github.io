import fs from 'node:fs';

const read = p => fs.readFileSync(p, 'utf8');
const must = (cond, msg) => { if (!cond) throw new Error(msg); };
const includes = (text, value, label=value) => must(text.includes(value), `missing: ${label}`);

const root = 'learning-sprint/shoshi';
const ios = `${root}/ios`;
const project = read(`${ios}/project.yml`);
const prepare = read(`${ios}/prepare-ios.sh`);
const privacyManifest = read(`${ios}/PrivacyInfo.xcprivacy`);
const capabilityPatch = read(`${ios}/apply-xcode-capabilities.py`);
const codemagic = read(`${ios}/codemagic-shoshi.yml`);
const metadata = read(`${root}/app-store/APP_STORE_METADATA_JA.md`);
const packet = read(`${root}/app-store/APPLE_CONNECT_PACKET.md`);
const review = read(`${root}/app-store/APP_REVIEW_NOTES_JA.md`);
const storekitPlan = read(`${root}/app-store/STOREKIT_TEST_PLAN.md`);
const swiftNames = ['App.swift','Models.swift','LearningLogic.swift','QuestionRepository.swift','StoreKitManager.swift','AppModel.swift','BackupDocument.swift','Theme.swift','Views.swift'];
const swift = swiftNames.map(n => read(`${ios}/${n}`)).join('\n');
const questions = JSON.parse(read(`${root}/content-loop/questions.generated.json`));

const BUNDLE = 'jp.allsunday1122.shoshi';
const APP_ID = '6799755748';
const PROFILE = 'shoshi_appstore';
const PRODUCT = 'jp.allsunday1122.shoshi.premium';
const VERSION = '1.0.0';
const SKU = 'shoshi-sprint-ios';
const SUPPORT = 'https://allsunday1122.github.io/learning-sprint/shoshi/support/';
const PRIVACY = 'https://allsunday1122.github.io/learning-sprint/shoshi/privacy/';
const ICON_SHA = 'c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506';

includes(project, `PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE}`, 'Xcode bundle ID');
includes(project, `MARKETING_VERSION: ${VERSION}`, 'version');
includes(project, 'UIInterfaceOrientationPortrait', 'portrait only');
includes(project, 'ShoshiSprintTests', 'unit-test target');
must(!project.includes('path: Web'), 'Web bundle is forbidden in native target');
includes(project, 'path: Resources', 'native bundled resources');

for (const token of ['import WebKit','WKWebView','UIViewRepresentable','loadFileURL']) {
  must(!swift.includes(token), `WebView implementation forbidden: ${token}`);
}
for (const label of ['ホーム','模試','記録','設定']) includes(swift, label, `tab ${label}`);
for (const goal of ['Text("4問").tag(4)','Text("8問").tag(8)','Text("16問").tag(16)']) includes(swift, goal, `goal ${goal}`);
includes(swift, 'var dailyGoal = 8', 'default 8 questions');
includes(swift, 'correctStreak >= 3', 'weak release after 3 correct');
includes(swift, 'state.resume', 'resume state');
includes(swift, 'fileExporter', 'JSON export');
includes(swift, 'fileImporter', 'JSON import');
includes(swift, 'UserDefaults.standard', 'local native persistence');
includes(swift, `static let productID = "${PRODUCT}"`, 'IAP product');
includes(swift, 'Product.products(for:', 'StoreKit 2 products');
includes(swift, 'displayPrice', 'localized price');
includes(swift, 'Transaction.currentEntitlements', 'entitlements');
includes(swift, 'Transaction.updates', 'transaction updates');
includes(swift, 'AppStore.sync()', 'restore');
includes(swift, 'revocationDate == nil', 'revocation');
must(!/[¥￥]\s*\d/.test(swift), 'hard-coded yen price forbidden');

includes(capabilityPatch, 'com.apple.InAppPurchase', 'IAP capability');
includes(prepare, ICON_SHA, 'canonical icon SHA');
includes(prepare, '$RESOURCES/questions.generated.json', 'native question resource');
includes(prepare, 'WebKit/WKWebView', 'WebKit absence gate');
includes(privacyManifest, 'NSPrivacyAccessedAPICategoryUserDefaults', 'UserDefaults privacy category');
includes(privacyManifest, 'CA92.1', 'UserDefaults reason');

must(Array.isArray(questions) && questions.length === 210, 'questions must remain 210');
must(new Set(questions.map(q => q.id)).size === 210, 'question IDs must remain unique');
const special = questions.find(q => q.id === 'SHOSHI-R7-PM-33');
must(special && special.scoring_status === 'all_correct' && special.official_answer_no == null, 'R7 PM33 all_correct broken');

for (const text of [metadata, packet]) {
  includes(text, BUNDLE, 'submission bundle ID');
  includes(text, PRODUCT, 'submission IAP ID');
  includes(text, SUPPORT, 'support URL');
  includes(text, PRIVACY, 'privacy URL');
}
includes(packet, APP_ID, 'App Store Connect App ID');
includes(packet, PROFILE, 'Codemagic signing profile');
includes(packet, `SKU: \`${SKU}\``, 'SKU');
includes(packet, 'SwiftUI native', 'native implementation declaration');
includes(packet, 'testFlightInternalTestingOnly: true', 'internal TestFlight export');
includes(packet, '`submit_to_testflight`: true', 'automatic Internal TestFlight upload');
includes(packet, '`submit_to_app_store`: false', 'no App Store review submit');
includes(metadata, 'Type: Non-Consumable', 'IAP type');
includes(storekitPlan, 'Sandbox購入成功', 'purchase actual-device gate');
includes(storekitPlan, '購入を復元', 'restore actual-device gate');
includes(review, '法務省の公式アプリではありません', 'non-official disclaimer');
must(!review.includes('WKWebView'), 'review notes still describe WKWebView');

includes(codemagic, 'shoshi-ios:', 'Codemagic workflow');
includes(codemagic, `bundle_identifier: ${BUNDLE}`, 'Codemagic bundle');
includes(codemagic, APP_ID, 'Codemagic App Store Connect App ID');
includes(codemagic, PROFILE, 'Codemagic signing profile canonical value');
includes(codemagic, 'submit_to_testflight: true', 'Internal TestFlight upload');
includes(codemagic, 'submit_to_app_store: false', 'main review disabled');
must(!/submit_to_app_store:\s*true/.test(codemagic), 'App Store auto-submit forbidden');

console.log('PASS: Shoshi pure-native Apple/TestFlight preflight contract is internally consistent.');
console.log(`Bundle=${BUNDLE}`);
console.log(`AppStoreConnectAppID=${APP_ID}`);
console.log(`SigningProfile=${PROFILE}`);
console.log(`Product=${PRODUCT}`);
console.log(`Questions=${questions.length}`);
console.log(`CanonicalIconSHA=${ICON_SHA}`);