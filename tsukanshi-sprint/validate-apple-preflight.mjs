import fs from 'node:fs';

const read = (p) => fs.readFileSync(p, 'utf8');
const must = (cond, msg) => { if (!cond) throw new Error(msg); };
const includes = (text, value, label=value) => must(text.includes(value), `missing: ${label}`);

const root = 'tsukanshi-sprint';
const project = read(`${root}/native-ios/project.yml`);
const capabilityPatch = read(`${root}/ios/apply-xcode-capabilities.py`);
const codemagic = read('codemagic.yaml');
const metadata = read(`${root}/APP_STORE_METADATA_JA.md`);
const packet = read(`${root}/APPLE_CONNECT_PACKET.md`);
const storekitPlan = read(`${root}/STOREKIT_TEST_PLAN.md`);
const review = read(`${root}/APP_REVIEW_NOTES_JA.md`);
const rights = read(`${root}/past-exam-rights-audit-59-57.md`);

const BUNDLE = 'jp.allsunday1122.tsukanshi';
const PRODUCT = 'jp.allsunday1122.tsukanshi.premium';
const VERSION = '1.0.0';
const SUPPORT = 'https://allsunday1122.github.io/tsukanshi-sprint/support.html';
const PRIVACY = 'https://allsunday1122.github.io/tsukanshi-sprint/privacy.html';

includes(project, `PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE}`, 'native Xcode bundle id');
includes(project, `MARKETING_VERSION: ${VERSION}`, 'native Xcode marketing version');
includes(capabilityPatch, 'com.apple.InAppPurchase', 'generated-project In-App Purchase capability patch');
includes(capabilityPatch, 'enabled = 1;', 'enabled generated-project capability');

// Isolate exactly one top-level workflow. The previous split(marker)[1] consumed every
// workflow that followed tsukanshi-native-ios, causing unrelated submit flags to fail this app's gate.
const marker = '\n  tsukanshi-native-ios:';
const start = codemagic.indexOf(marker);
must(start >= 0, 'missing tsukanshi-native-ios workflow');
const bodyStart = start + marker.length;
const rest = codemagic.slice(bodyStart);
const nextWorkflow = rest.search(/\n  [A-Za-z0-9_-]+:\s*\n/);
const block = nextWorkflow >= 0 ? rest.slice(0, nextWorkflow) : rest;
must((codemagic.match(/\n  tsukanshi-native-ios:/g) || []).length === 1, 'tsukanshi-native-ios workflow must be unique');

includes(block, 'app_store_connect: "Codemagic Shiwake Swipe"', 'Codemagic ASC integration');
includes(block, 'distribution_type: app_store', 'App Store distribution');
includes(block, `BUNDLE_ID: ${BUNDLE}`, 'Codemagic BUNDLE_ID');
includes(block, 'tsukanshi_appstore', 'Codemagic signing profile');
includes(block, 'testFlightInternalTestingOnly', 'internal TestFlight only export');
includes(block, 'apply-xcode-capabilities.py', 'Codemagic generated-project capability normalization');
includes(block, 'submit_to_testflight: false', 'no automatic TestFlight upload');
includes(block, 'submit_to_app_store: false', 'no automatic App Store review submission');
includes(block, 'CM_BUILD_NUMBER', 'CI build number');
includes(block, 'TsukanshiNative.xcodeproj', 'pure SwiftUI Xcode project');

for (const text of [metadata, packet]) {
  includes(text, BUNDLE, 'submission bundle id');
  includes(text, PRODUCT, 'submission IAP id');
  includes(text, SUPPORT, 'support URL');
  includes(text, PRIVACY, 'privacy URL');
}
includes(packet, 'SKU: `tsukanshi-sprint-ios`', 'fixed SKU');
includes(packet, 'Type: Non-Consumable', 'IAP type');
includes(packet, '`submit_to_app_store`: false', 'manual App Review gate');
includes(storekitPlan, PRODUCT, 'StoreKit test product id');
includes(storekitPlan, 'Sandbox購入成功', 'Sandbox purchase gate');
includes(storekitPlan, '復元で解放', 'Sandbox restore gate');
includes(review, '税関・財務省の公式アプリではありません', 'review disclaimer');
includes(rights, 'WCO', 'third-party rights audit');

must(!/submit_to_app_store:\s*true/.test(block), 'App Store auto-submit must stay disabled');
must(!/submit_to_testflight:\s*true/.test(block), 'TestFlight auto-submit must stay disabled');
must(!/WKWebView|import WebKit/.test(block), 'native release workflow must not depend on WebKit');

console.log('PASS: Pure SwiftUI Apple signing/TestFlight preflight contract is internally consistent.');
console.log(`Bundle=${BUNDLE}`);
console.log(`Product=${PRODUCT}`);
console.log(`Version=${VERSION}`);
