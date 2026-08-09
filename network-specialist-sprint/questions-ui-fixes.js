'use strict';
(function(){
  const routingIds=new Set(['NW-R06-A2-004','NW-R06-A2-014','NW-R05-A2-003']);
  for(const q of (window.NW_EXAM_OCCURRENCES||[])){
    if(routingIds.has(q.id)) q.uiDomain='ルーティング・SDN';
  }
})();
