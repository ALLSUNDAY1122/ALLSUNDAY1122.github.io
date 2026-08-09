import fs from 'node:fs';

const read = (p) => fs.readFileSync(p, 'utf8');
const must = (cond, msg) => { if (!cond) throw new Error(msg); };
const includes = (text, value, label=value) => must(text.includes(value), `missing: ${label}`);

const root = 'tsukanshi-sprint';
const project = read(`${root}/ios/project.yml`);
const swift = read(`${root}/ios/App.swift`);
const codemagic = read('codemagic.yaml');
const metadata = read(`${root}/APP_STORE_METADATA_JA.md`);
const packet = read(`${root}/APPLE_CONNECT_PACKET.md`);
const review = read(`${root}/APP_REVIEW_NOTES_JA.md`);
const rights = read(`${root}/past-exam-rights-audit-59-57.md`);

const BUNDLE = 'jp.allsunday1122.tsukanshi';
const PRODUCT = 'jp.allsunday1122.tsukanshi.premium';
const VERSION = '1.0.0';
const SUPPORT = 'https://allsunday1122.github.io/tsukanshi-sprint/support.html';
const PRIVACY = 'https://allsunday1122.github.io/tsukanshi-sprint/privacy.html';

includes(project, `PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE}`, 'Xcode bundle id');
includes(project, `MARKETING_VERSION: ${VERSION}`, 'Xcode marketing version');
includes(swift, `static let productID = "${PRODUCT}"`, 'StoreKit product id');
includes(swift, 'Transaction.currentEntitlements', 'current entitlements');
includes(swift, 'Transaction.updates', 'transaction updates observer');
includes(swift, 'AppStore.sync()', 'restore purchases');
includes(swift, 'transaction.revocationDate == nil', 'revocation handling');

const marker = '\n  tsukanshi-ios:';
must(codemagic.includes(marker), 'missing tsukanshi-ios workflow');
const block = codemagic.split(marker, 2)[1];
includes(block, 'app_store_connect: codemagic', 'Codemagic ASC integration');
includes(block, 'distribution_type: app_store', 'App Store distribution');
includes(block, `bundle_identifier: ${BUNDLE}`, 'Codemagic bundle id');
includes(block, `BUNDLE_ID: ${BUNDLE}`, 'Codemagic BUNDLE_ID');
includes(block, 'testFlightInternalTestingOnly', 'internal TestFlight only export');
includes(block, 'submit_to_testflight: false', 'no automatic beta-review submission');
includes(block, 'submit_to_app_store: false', 'no automatic App Store review submission');
includes(block, 'CM_BUILD_NUMBER', 'CI build number');

for (const text of [metadata, packet]) {
  includes(text, BUNDLE, 'submission bundle id');
  includes(text, PRODUCT, 'submission IAP id');
  includes(text, SUPPORT, 'support URL');
  includes(text, PRIVACY, 'privacy URL');
}
includes(packet, 'SKU: `tsukanshi-sprint-ios`', 'fixed SKU');
includes(packet, 'Type: Non-Consumable', 'IAP type');
includes(packet, '`submit_to_app_store`: false', 'manual App Review gate');
includes(review, '税関・財務省の公式アプリではありません', 'review disclaimer');
includes(rights, 'WCO', 'third-party rights audit');

must(!/submit_to_app_store:\s*true/.test(block), 'App Store auto-submit must stay disabled');

console.log('PASS: Apple signing/TestFlight preflight contract is internally consistent.');
console.log(`Bundle=${BUNDLE}`);
console.log(`Product=${PRODUCT}`);
console.log(`Version=${VERSION}`);
