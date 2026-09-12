'use strict';
(function(){
const TARGET=new Set(['L214','L216','P133','S173','S176','S177','S178','S179','S180']);
for(const q of QUESTIONS){
  if(!TARGET.has(q.id))continue;
  const condition=String(q.question).split('。')[0];
  q.detail=`${q.detail} 本問では「${condition}」の条件を個別に当てはめて判断する。`;
}
})();
