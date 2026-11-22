const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const paywall=fs.readFileSync('app/paywall.tsx','utf8');
const config=fs.readFileSync('app.config.ts','utf8');
test('payment screen uses a Safe Area container and fixed non-scrolling header',()=>{
  assert.match(paywall,/import \{ SafeAreaView \} from 'react-native-safe-area-context'/);
  assert.match(paywall,/<SafeAreaView style=\{styles\.safeArea\} edges=\{\['top','bottom'\]\}>/);
  assert.ok(paywall.indexOf('<View style={styles.fixedHeader}>')<paywall.indexOf('<ScrollView'));
  assert.match(paywall,/safeArea:\{flex:1/);
  assert.match(paywall,/scroll:\{flex:1\}/);
});
test('close button has at least 44-point hit area and accessible label',()=>{
  assert.match(paywall,/accessibilityRole="button"/);
  assert.match(paywall,/accessibilityLabel="閉じる"/);
  assert.match(paywall,/onPress=\{\(\)=>router\.back\(\)\}/);
  assert.match(paywall,/minHeight:44/);
  assert.match(paywall,/× 閉じる/);
  assert.doesNotMatch(paywall,/label="戻る"/);
});
test('current entitlement and subscription management remain intact',()=>{
  assert.match(paywall,/showManageSubscriptionsIOS\(\)/);
  assert.match(paywall,/current\?'ご利用中'/);
  assert.match(paywall,/disabled=\{current\|\|busy/);
  assert.match(config,/buildNumber: '20'/);
});
