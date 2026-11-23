/* FP2 development preview: cache app shell and canonical bank for offline reading.
   No release entitlement is inferred from cached content. */
const CACHE='fp2-ui-master21-20261123-r2-312';
const ASSETS=['./','./index.html','./fp2-approved-bank.js','./questions/canonical/approved-questions-20261123.json','./manifest.json','./icon.svg'];
self.addEventListener('install',event=>{
 event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
 event.waitUntil(caches.keys().then(names=>Promise.all(names.filter(name=>name.startsWith('fp2-ui-master21-')&&name!==CACHE).map(name=>caches.delete(name)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
 const request=event.request;
 if(request.method!=='GET'||new URL(request.url).origin!==self.location.origin)return;
 const path=new URL(request.url).pathname;
 const liveFirst=path.endsWith('/index.html')||path.endsWith('/approved-questions-20261123.json')||path.endsWith('/fp2-approved-bank.js')||path.endsWith('/fp2-manabi-sprint/');
 if(liveFirst){
  event.respondWith(fetch(request).then(response=>{
   if(response.ok){const copy=response.clone();event.waitUntil(caches.open(CACHE).then(cache=>cache.put(request,copy)));}
   return response;
  }).catch(async()=> (await caches.match(request))||Response.error()));
 }else{
  event.respondWith(caches.match(request).then(hit=>hit||fetch(request).then(response=>{
   if(response.ok){const copy=response.clone();event.waitUntil(caches.open(CACHE).then(cache=>cache.put(request,copy)));}
   return response;
  })));
 }
});
