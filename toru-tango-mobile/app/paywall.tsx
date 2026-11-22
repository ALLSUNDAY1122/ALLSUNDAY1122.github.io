import { useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Platform, ScrollView, StyleSheet, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useIAP } from 'expo-iap';
import { AppButton, colors } from '@/src/components/ui';
import { getTransactionJws, SUBSCRIPTION_IDS } from '@/src/services/iap';

const POLICY='https://allsunday1122.github.io/toru-tango/privacy-policy.html';
const EULA='https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const PLAN_NAMES: Record<string,string>={
  [SUBSCRIPTION_IDS[0]]:'スタンダード（100回/月）',
  [SUBSCRIPTION_IDS[1]]:'ライト（50回/月）'
};
function entitlementEndpoint() {
  const url=process.env.EXPO_PUBLIC_AI_API_URL?.trim()||'';
  return url.replace(/\/generate\/?$/,'')+'/entitlement';
}
async function verifyPurchase(jws: string) {
  const response=await fetch(entitlementEndpoint(),{
    method:'POST',
    headers:{'X-Toru-Tango-Transaction-JWS':jws,'Content-Type':'application/json'},
    body:'{}'
  });
  if(!response.ok)throw Error('購入検証に失敗しました');
  const data=await response.json() as {active?:boolean};
  if(!data.active)throw Error('有効な購入情報を確認できませんでした');
}

export default function PaywallScreen() {
  const [status,setStatus]=useState('');
  const [busy,setBusy]=useState(false);
  const {connected,subscriptions,fetchProducts,requestPurchase,finishTransaction}=useIAP({
    onPurchaseSuccess:async purchase=>{
      try {
        const jws=purchase.purchaseToken;
        if(!jws)throw Error('StoreKit署名情報がありません');
        await verifyPurchase(jws);
        await finishTransaction({purchase,isConsumable:false});
        setStatus('購入を確認しました。クラウドAI利用枠が反映されます。');
      } catch (error) {
        setStatus(error instanceof Error ? error.message : '購入確認に失敗しました');
      } finally {setBusy(false);}
    },
    onPurchaseError:error=>{setStatus(error.message||'購入が完了しませんでした');setBusy(false);}
  });
  useEffect(()=>{
    if(connected)void fetchProducts({skus:[...SUBSCRIPTION_IDS],type:'subs'}).catch(error=>setStatus(String(error)));
  },[connected,fetchProducts]);

  const purchase=async(productId:string)=>{
    if(!connected){setStatus('App Storeに接続できません。');return;}
    setBusy(true);
    try { await requestPurchase({request:{apple:{sku:productId}},type:'subs'}); }
    catch(error){setStatus(error instanceof Error?error.message:'購入を開始できませんでした');setBusy(false);}
  };
  const restore=async()=>{
    setBusy(true);
    try{
      const jws=await getTransactionJws();
      if(!jws){setStatus('有効な購入が見つかりませんでした。');return;}
      await verifyPurchase(jws);
      setStatus('購入を復元しました。');
    }catch(error){setStatus(error instanceof Error?error.message:'復元に失敗しました');}
    finally{setBusy(false);}
  };
  return (
    <ScrollView contentContainerStyle={styles.page}>
      <AppButton label="戻る" variant="secondary" onPress={()=>router.back()} />
      <Text style={styles.title}>クラウドAIプラン</Text>
      <Text style={styles.body}>Gemini作問とGemini OCRの合計利用回数を増やせます。無料は月5回です。端末内のApple Vision OCR・Foundation Models・簡易作問は回数に含みません。</Text>
      {Platform.OS==='ios' ? SUBSCRIPTION_IDS.map(id=>{
        const product=subscriptions.find(s=>s.id===id);
        return <View style={styles.plan} key={id}>
          <Text style={styles.planTitle}>{PLAN_NAMES[id]}</Text>
          <Text style={styles.price}>{product?.displayPrice ? product.displayPrice+'/月' : '価格を読み込み中'}</Text>
          <AppButton label={product?.displayPrice ? 'このプランに登録' : 'App Store価格を取得できません'} disabled={!product?.displayPrice || busy} onPress={()=>void purchase(id)} />
        </View>;
      }): <Text>iPhoneのApp Storeで利用できます。</Text>}
      {busy?<ActivityIndicator />:null}
      {status?<Text accessibilityRole="alert" style={styles.status}>{status}</Text>:null}
      <Text style={styles.body}>各プランは1か月ごとに自動更新され、解約しない限り課金が継続します。更新前にiPhoneの設定からサブスクリプションを管理・解約できます。プラン変更時の適用時期と請求はApp Storeの規則に従います。</Text>
      <AppButton label="購入を復元" variant="secondary" disabled={busy} onPress={()=>void restore()} />
      <AppButton label="プライバシーポリシー" variant="secondary" onPress={()=>void Linking.openURL(POLICY)} />
      <AppButton label="利用規約（Apple標準EULA）" variant="secondary" onPress={()=>void Linking.openURL(EULA)} />
    </ScrollView>
  );
}
const styles=StyleSheet.create({
 page:{padding:20,paddingBottom:60,gap:14,backgroundColor:colors.background},
 title:{fontSize:25,fontWeight:'800',color:colors.text},
 body:{fontSize:14,lineHeight:22,color:colors.text},
 plan:{padding:18,borderRadius:14,backgroundColor:colors.surface,borderWidth:1,borderColor:colors.border,gap:10},
 planTitle:{fontWeight:'800',fontSize:17,color:colors.text},
 price:{fontSize:20,fontWeight:'700',color:colors.text},
 status:{fontSize:14,color:colors.text}
});
