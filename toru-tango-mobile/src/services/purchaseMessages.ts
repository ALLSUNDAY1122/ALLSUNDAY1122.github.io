type PurchaseProblem = {code?:string|number|null;message?:string|null};
function signature(input:unknown) {
  if(!input||typeof input!=='object')return {code:'',message:''};
  const error=input as PurchaseProblem;
  return {
    code:String(error.code??'').toLowerCase().replace(/[\\s_]/g,'-'),
    message:String(error.message??'').toLowerCase()
  };
}
export function isCancelledPurchase(error:unknown):boolean {
  const {code,message}=signature(error);
  return /user-cancel|cancelled|canceled/.test(code) ||
    /user cancell?ed|purchase cancell?ed|user canceled/.test(message);
}
export function purchaseErrorMessage(error:unknown):string {
  const {code,message}=signature(error);
  if(isCancelledPurchase(error))return '';
  if(/already-owned|alreadyowned|item-already-owned/.test(code)||/already owned|already purchased/.test(message))
    return 'このサブスクリプションは購入済みです。「サブスクリプションを管理」からプランをご確認ください。';
  if(/network|service-disconnected|connection|timeout/.test(code)||/network|connection|timed out/.test(message))
    return 'App Storeとの通信に失敗しました。接続状況を確認して再度お試しください。';
  if(/item-unavailable|sku-not-found|product-not-found/.test(code)||/not available|unavailable/.test(message))
    return '現在このプランを購入できません。時間をおいて再度お試しください。';
  if(/billing|payment|store/.test(code)||/billing|payment/.test(message))
    return 'App Storeの購入処理を利用できません。お支払い設定をご確認ください。';
  return '購入を完了できませんでした。時間をおいて再度お試しください。';
}
