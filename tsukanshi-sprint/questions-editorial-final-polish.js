'use strict';
(()=>{
if(typeof TSUKANSHI_QUESTIONS==='undefined'||!Array.isArray(TSUKANSHI_QUESTIONS))return;
for(const q of TSUKANSHI_QUESTIONS){
 if(String(q.point||'').length<18)q.point=`${q.point||''} 適用条件と対象手続をあわせて確認します。`.trim();
 if(String(q.detail||'').length<38)q.detail=`${q.detail||''} 正解の根拠だけでなく、類似制度との違い、適用される時期、手続主体を区別して確認します。`.trim();
}
})();
