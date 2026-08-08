'use strict';
(function(){
  const nativeSet=window.setInterval.bind(window);
  const nativeClear=window.clearInterval.bind(window);
  let active=null;
  window.setInterval=function(fn,delay,...args){
    if(active!==null) nativeClear(active);
    active=nativeSet(fn,delay,...args);
    return active;
  };
  window.clearInterval=function(id){
    nativeClear(id);
    if(id===active) active=null;
  };
})();
