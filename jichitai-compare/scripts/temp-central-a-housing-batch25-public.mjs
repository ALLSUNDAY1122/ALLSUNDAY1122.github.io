import fs from 'node:fs';
import path from 'node:path';
import {setTimeout as sleep} from 'node:timers/promises';

const unavailable='子育て世帯・新婚世帯を対象要件とする現行の住宅取得・改修・家賃支援制度は、公式情報で確認できない。';
const targets=[
 {code:'27227',name:'東大阪市',status:'unavailable',summary:unavailable,source:'https://www.city.higashiosaka.lg.jp/0000005748.html'},
 {code:'27228',name:'泉南市',status:'unavailable',summary:unavailable,source:'https://www.city.sennan.lg.jp/kakuka/toshiseibi/jutakushidou/jutakukenchiku/taishin/1577079347548.html'},
 {code:'27229',name:'四條畷市',status:'verified',summary:'40歳未満の夫婦または20歳未満の子と同居する世帯が市内中古住宅を取得・改修する場合、工事費の2分の1、最大100万円を補助する。',source:'https://www.city.shijonawate.lg.jp/page/19-62432.html'},
 {code:'27230',name:'交野市',status:'verified',summary:'中古住宅を取得して市外から転入し、中学生以下の子がいる世帯へ、基本補助に子ども1人につき5万円を加算する。',source:'https://www.city.katano.osaka.jp/docs/2022030300026/'},
 {code:'27232',name:'阪南市',status:'unavailable',summary:unavailable,source:'https://www.city.hannan.lg.jp/kakuka/toshi/toshi/taishinka/1597994486626.html'}
];
const base='https://allsunday1122.github.io/jichitai-compare';
let final=null;
for(let attempt=1;attempt<=30;attempt++){
 const nonce=`${Date.now()}-${attempt}`;
 const pageChecks=[];
 for(const target of targets){
  try{
   const url=`${base}/municipality/${target.code}/?audit=${nonce}`;
   const response=await fetch(url,{headers:{'cache-control':'no-cache','user-agent':'CentralAHousingBatch25Audit/1.0'}});
   const html=await response.text();
   const sourceMatches=html.includes(target.source)||html.includes(target.source.replaceAll('&','&amp;'));
   const summaryMatches=html.includes(target.summary);
   const statusMatches=target.status==='unavailable'?(html.includes('公式情報で詳細未確認')||html.includes('利用可能な制度情報を確認できません')):true;
   pageChecks.push({code:target.code,name:target.name,expectedStatus:target.status,url,httpStatus:response.status,sourceMatches,summaryMatches,statusMatches,success:response.status===200&&sourceMatches&&summaryMatches&&statusMatches});
  }catch(error){pageChecks.push({code:target.code,name:target.name,error:String(error),success:false});}
 }
 let jsonCheck={success:false};
 try{
  const response=await fetch(`${base}/data/generated/municipalities.json?audit=${nonce}`,{headers:{'cache-control':'no-cache','user-agent':'CentralAHousingBatch25Audit/1.0'}});
  const payload=await response.json();
  const municipalities=Array.isArray(payload)?payload:(payload.municipalities||[]);
  const records=targets.map(target=>{
   const municipality=municipalities.find(item=>item.code===target.code);
   const service=municipality?.services?.housingSupport;
   return {code:target.code,found:Boolean(municipality),statusMatches:service?.status===target.status,summaryMatches:service?.summary===target.summary,sourceMatches:service?.source?.url===target.source,success:Boolean(municipality)&&service?.status===target.status&&service?.summary===target.summary&&service?.source?.url===target.source};
  });
  const serviceCount=municipalities.reduce((sum,item)=>sum+Object.keys(item.services||{}).length,0);
  jsonCheck={httpStatus:response.status,municipalityCount:municipalities.length,serviceCount,records,success:response.status===200&&municipalities.length===1741&&serviceCount===15669&&records.every(v=>v.success)};
 }catch(error){jsonCheck={error:String(error),success:false};}
 final={attempt,pageChecks,jsonCheck,success:pageChecks.every(v=>v.success)&&jsonCheck.success};
 if(final.success) break;
 await sleep(10000);
}
const evidence={schemaVersion:'1.0.0',auditId:'central-a-housing-classification-batch25-public-verification-20260726',generatedAt:new Date().toISOString(),regionalPullRequest:3849,nationalSyncPullRequest:3851,verificationPullRequest:Number(process.env.PR_NUMBER),verificationWorkflowRunId:Number(process.env.RUN_ID),expectedUnavailableCount:3,expectedVerifiedCount:2,...final,releaseBlocker:final.success?'none':'public_verification_failed'};
const out='jichitai-compare/operations/audits/central-a-housing-classification-batch25-public-verification-20260726.json';
fs.mkdirSync(path.dirname(out),{recursive:true});
fs.writeFileSync(out,JSON.stringify(evidence,null,2)+'\n');
for(const p of ['jichitai-compare/operations/control/central-a-housing-batch25-public-trigger-20260726.json','jichitai-compare/scripts/temp-central-a-housing-batch25-public.mjs']) if(fs.existsSync(p)) fs.rmSync(p);
if(!final.success) throw new Error('Public verification failed after retries');
