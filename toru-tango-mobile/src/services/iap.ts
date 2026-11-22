import { Platform } from 'react-native';
import { getAvailablePurchases, initConnection } from 'expo-iap';

export const SUBSCRIPTION_IDS = [
  'com.allsunday1122.torutango.pro.monthly100',
  'com.allsunday1122.torutango.pro.monthly50'
] as const;

let initialized = false;
export async function getTransactionJws(): Promise<string | null> {
  if (Platform.OS !== 'ios') return null;
  if (!initialized) { await initConnection(); initialized = true; }
  const purchases = await getAvailablePurchases();
  const now=Date.now();
  const active=purchases.filter(p=>SUBSCRIPTION_IDS.some(id=>id===p.productId) &&
    'expirationDateIOS' in p && typeof p.expirationDateIOS === 'number' && p.expirationDateIOS > now &&
    typeof p.purchaseToken === 'string' && p.purchaseToken.split('.').length===3)
    .sort((a,b)=>(('expirationDateIOS' in b ? b.expirationDateIOS : 0)||0)-(('expirationDateIOS' in a ? a.expirationDateIOS : 0)||0));
  return active[0]?.purchaseToken || null;
}
