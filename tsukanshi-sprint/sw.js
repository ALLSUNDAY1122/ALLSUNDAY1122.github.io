const CACHE='tsukanshi-sprint-v22-buttons';
const ASSETS=['./','./index.html','./style-v21.css?v=20260809-1034','./bootstrap-v21.js?v=20260809-1034','./app-v21.js?v=20260809-1034','./manifest.json','./icon.svg','./questions.js','./sources-v02.js','./questions-v02-tb.js','./questions-v02-ks1.js','./questions-v02-ks2.js','./questions-v02-ks3.js','./questions-v02-ks4.js','./questions-v02-jm1.js','./questions-v02-jm2.js','./questions-v02-jm3.js','./questions-v02-jm4.js','./sources-v03.js','./questions-v03-tb.js'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  if(url.origin!==self.location.origin)return;
  event.respondWith(
    fetch(event.request).then(response=>{
      if(response&&response.ok){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));}
      return response;
    }).catch(async()=>{
      const hit=await caches.match(event.request);
      if(hit)return hit;
      if(event.request.mode==='navigate'){const page=await caches.match('./index.html');if(page)return page;}
      return Response.error();
    })
  );
});
