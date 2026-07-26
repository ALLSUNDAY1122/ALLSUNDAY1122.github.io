import fs from 'node:fs';
import path from 'node:path';

const root='jichitai-compare';
const checkedAt='2026-07-26';
const updatedAt='2026-07-26T11:34:00+09:00';
const pr=Number(process.env.PR_NUMBER);
const run=Number(process.env.RUN_ID);
const unavailable='子育て世帯・新婚世帯を対象要件とする現行の住宅取得・改修・家賃支援制度は、公式情報で確認できない。';
const keys=['childMedical','sickChildCare','childcareFee','schoolMeals','postpartumCare','temporaryChildcare','housingSupport','bulkyWaste','disasterPrevention'];
const replacements={
'27227':{type:'general_seismic_support_misclassification',service:{status:'unavailable',summary:unavailable,details:{confirmedGeneralProgram:'旧耐震基準の木造住宅を対象とする耐震改修工事等の補助制度を確認した。',classificationReview:'年齢・所得・建物条件による一般耐震支援であり、子ども・新婚・三世代等を対象要件とする住宅取得・改修・家賃支援ではないため、子育て住宅支援として登録しない。',childSpecificConditionConfirmed:false},source:{url:'https://www.city.higashiosaka.lg.jp/0000005748.html',checkedAt}}},
'27228':{type:'general_seismic_support_misclassification',service:{status:'unavailable',summary:unavailable,details:{confirmedGeneralProgram:'旧耐震基準の民間木造住宅を対象とする耐震改修設計・工事・耐震シェルター補助を確認した。',classificationReview:'建築年、耐震性、所得等を条件とする一般耐震支援で、子育て世帯・新婚世帯固有の住宅条件や加算を現行公式情報で確認できないため、子育て住宅支援として登録しない。',childSpecificConditionConfirmed:false},source:{url:'https://www.city.sennan.lg.jp/kakuka/toshiseibi/jutakushidou/jutakukenchiku/taishin/1577079347548.html',checkedAt}}},
'27229':{type:'replace_with_current_child_young_household_renovation',service:{status:'verified',summary:'40歳未満の夫婦または20歳未満の子と同居する世帯が市内中古住宅を取得・改修する場合、工事費の2分の1、最大100万円を補助する。',details:{program:'四條畷市若者世帯等定住促進既存住宅リフォーム補助金',target:'40歳未満の夫婦または20歳未満の子どもと同居し、市内賃貸住宅・親所有住宅・市外住宅のいずれかに居住している世帯',housing:'前年1月1日以降に売買・相続・贈与で取得した市内中古住宅',amount:'対象リフォーム工事費の2分の1以内。基本上限10万円に空き家40万円、過去居住20万円、親市内居住20万円、市外転入10万円を加算し最大100万円',application:'各年度4月1日から12月28日まで、工事着手前に申請',currentStatus:'2026年5月15日時点で受付中。6件目以降は予算残額の範囲内'},source:{url:'https://www.city.shijonawate.lg.jp/page/19-62432.html',checkedAt}}},
'27230':{type:'replace_with_current_child_home_acquisition_addition',service:{status:'verified',summary:'中古住宅を取得して市外から転入し、中学生以下の子がいる世帯へ、基本補助に子ども1人につき5万円を加算する。',details:{program:'令和8年度交野市住宅取得流通促進支援事業補助金',housing:'2025年1月1日以降に取得した2015年以前建築の市内中古住宅',residence:'2026年1月1日から12月31日までに対象住宅へ住民票を異動すること',basicAmount:'建築年・住宅種別に応じ5万円、20万円または40万円',additions:'旧耐震建物40万円、市外からの転入5万円、市外転入かつ中学生以下の子どもがいる場合は子ども1人につき5万円',application:'事前相談後、申請書・要件調書・誓約書等を提出'},source:{url:'https://www.city.katano.osaka.jp/docs/2022030300026/',checkedAt}}},
'27232':{type:'general_seismic_support_misclassification',service:{status:'unavailable',summary:unavailable,details:{confirmedGeneralProgram:'旧耐震基準の住宅等を対象とする耐震診断・耐震改修・耐震シェルター補助を確認した。',classificationReview:'建築年・耐震性・所得を条件とする一般耐震支援であり、子育て世帯・新婚世帯固有の住宅取得・改修・家賃支援を現行公式情報で確認できないため、子育て住宅支援として登録しない。',childSpecificConditionConfirmed:false},source:{url:'https://www.city.hannan.lg.jp/kakuka/toshi/toshi/taishinka/1597994486626.html',checkedAt}}}
};
const records=[];
for(const [code,entry] of Object.entries(replacements)){
 const pref=code.slice(0,2);
 const dataPath=path.join(root,'data/municipalities',pref,`${code}.json`);
 const taskPath=path.join(root,'operations/tasks',`${code}.json`);
 const m=JSON.parse(fs.readFileSync(dataPath,'utf8'));
 const before=structuredClone(m.services.housingSupport);
 m.services.housingSupport=entry.service;
 m.updatedAt=checkedAt;
 fs.writeFileSync(dataPath,JSON.stringify(m)+'\n');
 const task=JSON.parse(fs.readFileSync(taskPath,'utf8'));
 const statuses=Object.values(m.services).map(v=>v.status);
 Object.assign(task,{status:'merged',currentService:null,nextServiceIndex:9,completedServices:keys,verifiedCount:statuses.filter(v=>v==='verified').length,researchingCount:statuses.filter(v=>v==='researching').length,unavailableCount:statuses.filter(v=>v==='unavailable').length,needsMediumReviewCount:statuses.filter(v=>v==='needs_medium_review').length,currentBranch:'region/central',pullRequestNumber:pr,lastCheckedAt:checkedAt,lastUpdatedAt:updatedAt,lastUpdatedBy:'統括B②'});
 task.officialSources=[...new Set(keys.map(k=>m.services[k]?.source?.url).filter(Boolean))];
 task.notes=[...(task.notes||[]),`2026-07-26: 住宅支援分類第25群で公式情報を独立確認し、${entry.type}としてhousingSupportを更新。`];
 task.blockers=task.blockers||[];
 fs.writeFileSync(taskPath,JSON.stringify(task)+'\n');
 records.push({code,name:m.name,service:'housingSupport',correctionType:entry.type,beforeStatus:before.status,afterStatus:entry.service.status,beforeSummary:before.summary,afterSummary:entry.service.summary,officialSource:entry.service.source.url});
}
const audit={schemaVersion:'1.0.0',auditId:'central-a-housing-classification-batch25-decisions-20260726',decidedAt:updatedAt,session:'中日本調査班A',coordinatorSession:'統括B②',category:'generalHousingMisclassification',regionalPullRequestNumber:pr,runnerWorkflowRunId:run,reviewedMunicipalityCount:5,confirmedCorrectionCount:5,statusToUnavailableCount:3,verifiedReplacementCount:2,corrected:records,causeScan:{previousRemainingCandidates:54,reviewedHighRiskCandidates:5,remainingCandidates:49},issue3141:{unresolvedItemCount:19,unresolvedMunicipalityCount:19,changed:false},policy:['一般耐震制度だけを子育て世帯向け住宅支援として登録しない','子ども・若者世帯の明示要件または子ども加算を現行公式本文で確認できる制度へ差し替える','制度目的だけでなく交付要件・金額・申請期間を利用者向け公式ページで確認する'],result:{unresolvedConfirmedErrorCount:0,releaseBlocker:'none'}};
fs.writeFileSync(path.join(root,'operations/audits/central-a-housing-classification-batch25-decisions-20260726.json'),JSON.stringify(audit,null,2)+'\n');
const checkpointPath=path.join(root,'operations/control/session-checkpoints/central-a.json');
const cp=JSON.parse(fs.readFileSync(checkpointPath,'utf8'));
Object.assign(cp,{updatedAt,pullRequestNumber:pr,ciStatus:'success',stateSyncPullRequestNumber:pr,nextAction:'一般住宅・移住制度の分類候補残49件と弱い主出典残33件を、利用者向け公式情報で原因別に継続判定する。Issue #3141の19項目は公式利用条件公開時のみ解消する。'});
Object.assign(cp.qualityReaudit,{latestCompletedAt:updatedAt,latestRegionalPullRequestNumber:pr,latestCiRunNumber:run,correctedMunicipalitiesRechecked:179,primarySourceSlotsRechecked:611});
cp.qualityReaudit.candidateCounts.generalHousingMisclassification=49;
cp.qualityReaudit.confirmedCorrections.push(...records.map(r=>({type:r.correctionType,code:r.code,service:'housingSupport',name:r.name})));
cp.qualityReaudit.nextPriority=['一般住宅・移住制度の分類候補残49件','弱い主出典残33候補','Issue #3141の19項目を公式利用条件公開時のみ解消'];
cp.qualityReaudit.latestHousingBatch={batch:25,status:'regional_corrected_pending_national_sync',reviewedMunicipalityCount:5,confirmedCorrectionCount:5,statusToUnavailableCount:3,verifiedReplacementCount:2,remainingCandidates:49,regionalPullRequestNumber:pr,regionalWorkflowRunId:run,blocker:null};
cp.lastAction='住宅支援分類第25群として、東大阪市・泉南市・阪南市の一般耐震制度をunavailableへ修正し、四條畷市・交野市を現行の子育て世帯向け住宅支援へ差し替えた。';
fs.writeFileSync(checkpointPath,JSON.stringify(cp,null,2)+'\n');
const regionPath=path.join(root,'operations/control/regions/central.json');
const region=JSON.parse(fs.readFileSync(regionPath,'utf8'));
region.updatedAt=updatedAt; region.latestCentralAHousingBatch=cp.qualityReaudit.latestHousingBatch; region.lastAction=cp.lastAction;
fs.writeFileSync(regionPath,JSON.stringify(region,null,2)+'\n');
const trigger=path.join(root,'operations/control/central-a-housing-batch25-trigger-20260726.json');
if(fs.existsSync(trigger)) fs.rmSync(trigger);
