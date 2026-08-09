(()=>{
'use strict';
const Q=window.KANGOSHI_QUESTIONS||[];
const major=(s)=>{
 s=String(s||'');
 if(/生命維持/.test(s))return'人体の構造と機能';
 if(/感染症|薬理|免疫/.test(s))return'疾病の成り立ちと回復の促進';
 if(/公衆衛生|社会保障/.test(s))return'健康支援と社会保障制度';
 if(/感染予防|安全|酸素療法|与薬|清潔|観察|褥瘡|コミュニケーション|排泄|栄養$|呼吸$|循環$|体温|疼痛|輸液|患者安全|安楽|記録/.test(s))return'基礎看護学';
 if(/在宅/.test(s))return'地域・在宅看護論';
 if(/循環器|呼吸器|消化器|内分泌|腎|泌尿|脳神経|運動器|血液|周術期|がん|終末期|糖尿病|栄養・代謝/.test(s))return'成人看護学';
 if(/老年/.test(s))return'老年看護学';
 if(/小児/.test(s))return'小児看護学';
 if(/母性/.test(s))return'母性看護学';
 if(/精神/.test(s))return'精神看護学';
 if(/災害|倫理|個人情報|看護管理|救急/.test(s))return'看護の統合と実践';
 return'その他・横断';
};
for(const q of Q)q.majorSubject=major(q.subject);
if(window.KANGOSHI_CONTENT_META)window.KANGOSHI_CONTENT_META.taxonomy='MHLW nursing exam 11 subjects / explicit majorSubject v1';
})();