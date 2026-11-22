import { Platform } from 'react-native';
import { getAvailablePurchases, initConnection } from 'expo-iap';

export const SUBSCRIPTION_IDS = [
  'com.allsunday1122.torutango.pro.monthly100',
  'com.allsunday1122.torutango.pro.monthly50'
] as const;

let initialized = false;
export async function getTransactionJws(): Promise<string | null> {
  // StoreKit may reject a native request while offline or while no App Store account
  // is configured. Free-tier cloud AI must remain usable in that case.
  if (Platform.OS !== 'ios') return null;
  let purchases;
  try {
    if (!initialized) { await initConnection(); initialized = true; }
    purchases = await getAvailablePurchases();
  } catch (error) {
    // A native StoreKit error happens *before* fetch(/generate or /ocr).
    // Do not mistake it for a Worker/network failure. Server quotas remain enforced.
    console.warn('StoreKit entitlement lookup unavailable; using free tier',
      error instanceof Error ? error.name : 'unknown');
    return null;
  }
  const now=Date.now();
  const active=purchases.filter(p=>SUBSCRIPTION_IDS.some(id=>id===p.productId) &&
    'expirationDateIOS' in p && typeof p.expirationDateIOS === 'number' && p.expirationDateIOS > now &&
    typeof p.purchaseToken === 'string' && p.purchaseToken.split('.').length===3)
    .sort((a,b)=>(('expirationDateIOS' in b ? b.expirationDateIOS : 0)||0)-(('expirationDateIOS' in a ? a.expirationDateIOS : 0)||0));
  return active[0]?.purchaseToken || null;
}
