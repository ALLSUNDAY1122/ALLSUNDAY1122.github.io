/* FP2 offline-first static preview shell. Scope limited to this app. */
const CACHE_NAME="fp2-manabi-20261123-verbatim300-v4";
const APP_FILES=["./","./index.html","./fp2-approved-bank.js","./questions/canonical/approved-questions-20261123.json","./manifest.webmanifest"];
self.addEventListener("install",event=>{
  event.waitUntil(caches.open(CACHE_NAME).then(cache=>cache.addAll(APP_FILES)).then(()=>self.skipWaiting()));
});
self.addEventListener("activate",event=>{
  event.waitUntil(caches.keys().then(names=>Promise.all(names.filter(n=>n.startsWith("fp2-manabi-")&&n!==CACHE_NAME).map(n=>caches.delete(n)))).then(()=>self.clients.claim()));
});
self.addEventListener("fetch",event=>{
  const request=event.request;
  if(request.method!=="GET")return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin||!url.pathname.startsWith(new URL(self.registration.scope).pathname))return;
  event.respondWith(fetch(request).then(response=>{
    if(response.ok&&response.type==="basic"){
      const copy=response.clone();
      event.waitUntil(caches.open(CACHE_NAME).then(cache=>cache.put(request,copy)));
    }
    return response;
  }).catch(()=>caches.match(request).then(hit=>hit||((request.mode==="navigate")?caches.match("./index.html"):Response.error()))));
});
