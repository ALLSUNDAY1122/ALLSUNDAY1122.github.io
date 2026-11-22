import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, AppState, Linking, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { showManageSubscriptionsIOS, useIAP } from 'expo-iap';
import { AppButton, colors } from '@/src/components/ui';
import { getTransactionJws, SUBSCRIPTION_IDS } from '@/src/services/iap';
import { isCancelledPurchase, purchaseErrorMessage } from '@/src/services/purchaseMessages';
import { refreshCloudUsage } from '@/src/services/cloudUsage';

const POLICY='https://allsunday1122.github.io/toru-tango/privacy-policy.html';
const EULA='https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const MANAGE_URL='https://apps.apple.com/account/subscriptions';
const PLAN_NAMES: Record<string,string>={
  [SUBSCRIPTION_IDS[0]]:'スタンダード（100回/月）',
  [SUBSCRIPTION_IDS[1]]:'ライト（50回/月）'
};
type Entitlement={active:boolean;limit:number;tier:string};
type EntitlementState={kind:'loading'|'free'|'active'|'error';productId:string|null};
function entitlementEndpoint() {
  const url=process.env.EXPO_PUBLIC_AI_API_URL?.trim()||'';
  if(!url.startsWith('https://'))throw new Error('AI接続先が設定されていません。');
  return url.replace(/\/generate\/?$/,'')+'/entitlement';
}
async function verifyPurchase(jws: string): Promise<Entitlement> {
  const response=await fetch(entitlementEndpoint(),{
    method:'POST',
    headers:{'X-Toru-Tango-Transaction-JWS':jws,'Content-Type':'application/json'},
    body:'{}'
  });
  if(!response.ok)throw Error('購入情報を確認できませんでした。接続を確認してください。');
  const data=await response.json() as Entitlement;
  if(!data.active)throw Error('有効な購入情報を確認できませんでした。');
  return data;
}
function productForEntitlement(entitlement:Entitlement):string|null {
  if(!entitlement.active)return null;
  if(entitlement.limit===100)return SUBSCRIPTION_IDS[0];
  if(entitlement.limit===50)return SUBSCRIPTION_IDS[1];
  return null;
}

export default function PaywallScreen() {
  const [status,setStatus]=useState('');
  const [busy,setBusy]=useState(false);
  const [entitlement,setEntitlement]=useState<EntitlementState>({kind:'loading',productId:null});
  const refreshEntitlement=useCallback(async()=>{
    setEntitlement({kind:'loading',productId:null});
    try {
      const jws=await getTransactionJws();
      if(!jws){setEntitlement({kind:'free',productId:null});return;}
      const verified=await verifyPurchase(jws);
      setEntitlement({kind:'active',productId:productForEntitlement(verified)});
      void refreshCloudUsage();
    }catch {
      // Unknown entitlement must not enable another purchase accidentally.
      setEntitlement({kind:'error',productId:null});
      setStatus('加入状況を確認できません。通信を確認して再読み込みしてください。');
    }
  },[]);
  useFocusEffect(useCallback(()=>{
    void refreshEntitlement();
  },[refreshEntitlement]));
  useEffect(()=>{
    const sub=AppState.addEventListener('change',state=>{
      if(state==='active')void refreshEntitlement();
    });
    return ()=>sub.remove();
  },[refreshEntitlement]);

  const {connected,subscriptions,fetchProducts,requestPurchase,finishTransaction}=useIAP({
    onPurchaseSuccess:async purchase=>{
      try {
        const jws=purchase.purchaseToken;
        if(!jws)throw Error('StoreKit署名情報がありません');
        await verifyPurchase(jws);
        await finishTransaction({purchase,isConsumable:false});
        setStatus('購入を確認しました。クラウドAI利用枠が反映されます。');
        await refreshEntitlement();
      }catch {
        setStatus('購入後の確認が完了しませんでした。「購入を復元」で再確認してください。');
      }finally{setBusy(false);}
    },
    onPurchaseError:error=>{
      if(isCancelledPurchase(error)){setStatus('');setBusy(false);return;}
      setStatus(purchaseErrorMessage(error));
      setBusy(false);
      void refreshEntitlement();
    }
  });
  useEffect(()=>{
    if(connected)void fetchProducts({skus:[...SUBSCRIPTION_IDS],type:'subs'})
      .catch(()=>setStatus('App Storeのプラン情報を取得できませんでした。再度お試しください。'));
  },[connected,fetchProducts]);

  const manage=async()=>{
    if(Platform.OS!=='ios')return;
    setStatus('');
    try {
      await showManageSubscriptionsIOS();
    }catch {
      try {await Linking.openURL(MANAGE_URL);}
      catch {setStatus('サブスクリプション管理画面を開けませんでした。iPhoneの「設定」→「サブスクリプション」から変更してください。');}
    }
  };
  const purchase=async(productId:string)=>{
    if(entitlement.kind==='loading'||entitlement.kind==='error'){
      setStatus('加入状況を確認してから購入してください。');
      return;
    }
    if(entitlement.kind==='active'){
      if(entitlement.productId===productId){
        setStatus('このプランをご利用中です。');
      }else {
        setStatus('プラン変更はiPhoneの「設定」→「サブスクリプション」から行えます。');
        await manage();
      }
      return;
    }
    if(!connected){setStatus('App Storeに接続できません。通信を確認してください。');return;}
    setStatus('');
    setBusy(true);
    try {
      // StoreKit results are delivered by onPurchaseSuccess/onPurchaseError.
      await requestPurchase({request:{apple:{sku:productId}},type:'subs'});
    }catch(error){
      if(!isCancelledPurchase(error))setStatus(purchaseErrorMessage(error));
      setBusy(false);
    }
  };
  const restore=async()=>{
    setBusy(true);
    setStatus('');
    try{
      const jws=await getTransactionJws();
      if(!jws){setStatus('有効な購入が見つかりませんでした。');return;}
      await verifyPurchase(jws);
      await refreshEntitlement();
      setStatus('購入を復元しました。');
    }catch {
      setStatus('購入を確認できませんでした。通信状態とApple Accountをご確認ください。');
    }finally{setBusy(false);}
  };

  const hasSubscription=entitlement.kind==='active';
  const isLoading=entitlement.kind==='loading';
  return (
    <SafeAreaView style={styles.safeArea} edges={['top','bottom']}>
      <View style={styles.fixedHeader}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="閉じる"
          accessibilityHint="クラウドAIプラン画面を閉じます"
          hitSlop={4}
          onPress={()=>router.back()}
          style={styles.closeButton}
        >
          <Text style={styles.closeLabel}>× 閉じる</Text>
        </Pressable>
      </View>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.page}
        keyboardShouldPersistTaps="handled"
      >
      <Text style={styles.title}>クラウドAIプラン</Text>
      <Text style={styles.body}>Gemini作問とGemini OCRの合計利用回数を増やせます。無料は月5回です。端末内のApple Vision OCR・Foundation Models・簡易作問は回数に含みません。</Text>
      {isLoading?<ActivityIndicator accessibilityLabel="加入状況を確認しています" />:null}
      {hasSubscription?<Text style={styles.activeNotice}>現在サブスクリプションをご利用中です。プラン変更はiPhoneの「設定」→「サブスクリプション」から行えます。</Text>:null}
      {entitlement.kind==='error'?<AppButton label="加入状況を再確認" onPress={()=>void refreshEntitlement()} />:null}
      {Platform.OS==='ios' ? SUBSCRIPTION_IDS.map(id=>{
        const product=subscriptions.find(s=>s.id===id);
        const current=hasSubscription&&entitlement.productId===id;
        const alternative=hasSubscription&&!current;
        return <View style={styles.plan} key={id}>
          <Text style={styles.planTitle}>{PLAN_NAMES[id]}{current?'　ご利用中':''}</Text>
          <Text style={styles.price}>{product?.displayPrice ? product.displayPrice+'/月' : '価格を読み込み中'}</Text>
          <AppButton
            label={current?'ご利用中':alternative?'サブスクリプションを管理':product?.displayPrice?'このプランに登録':'App Store価格を取得できません'}
            disabled={current||busy||isLoading||entitlement.kind==='error'||(!alternative&&!product?.displayPrice)}
            onPress={()=>void (alternative?manage():purchase(id))}
          />
        </View>;
      }): <Text>iPhoneのApp Storeで利用できます。</Text>}
      {hasSubscription?<AppButton label="サブスクリプションを管理" variant="secondary" onPress={()=>void manage()} />:null}
      {busy?<ActivityIndicator />:null}
      {status?<Text accessibilityRole="alert" style={styles.status}>{status}</Text>:null}
      <Text style={styles.body}>各プランは1か月ごとに自動更新され、解約しない限り課金が継続します。更新前にiPhoneの設定からサブスクリプションを管理・解約できます。プラン変更時の適用時期と請求はApp Storeの規則に従います。</Text>
      <AppButton label="購入を復元" variant="secondary" disabled={busy} onPress={()=>void restore()} />
      <AppButton label="プライバシーポリシー" variant="secondary" onPress={()=>void Linking.openURL(POLICY)} />
      <AppButton label="利用規約（Apple標準EULA）" variant="secondary" onPress={()=>void Linking.openURL(EULA)} />
      </ScrollView>
    </SafeAreaView>
  );
}
const styles=StyleSheet.create({
 safeArea:{flex:1,backgroundColor:colors.background},
 fixedHeader:{minHeight:56,paddingHorizontal:16,justifyContent:'center',backgroundColor:colors.background,borderBottomWidth:StyleSheet.hairlineWidth,borderBottomColor:colors.border},
 closeButton:{minHeight:44,minWidth:88,alignSelf:'flex-start',justifyContent:'center',alignItems:'center',paddingHorizontal:12,borderRadius:10},
 closeLabel:{fontSize:17,fontWeight:'700',color:colors.text},
 scroll:{flex:1},
 page:{padding:20,paddingBottom:60,gap:14,backgroundColor:colors.background},
 title:{fontSize:25,fontWeight:'800',color:colors.text},
 body:{fontSize:14,lineHeight:22,color:colors.text},
 activeNotice:{fontSize:14,lineHeight:22,color:colors.primaryDark,backgroundColor:colors.primarySoft,padding:12,borderRadius:12},
 plan:{padding:18,borderRadius:14,backgroundColor:colors.surface,borderWidth:1,borderColor:colors.border,gap:10},
 planTitle:{fontWeight:'800',fontSize:17,color:colors.text},
 price:{fontSize:20,fontWeight:'700',color:colors.text},
 status:{fontSize:14,color:colors.text}
});
