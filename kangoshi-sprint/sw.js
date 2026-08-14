const CACHE='kangoshi-sprint-v25-20260814-canonical-runtime1';
const ASSETS=[
 './','./index.html','./style.css',
 './questions.js','./questions-numeric.js','./questions-audit-v1.js','./question-taxonomy-v1.js',
 './exam-config.js','./scoring-overrides.js','./questions-runtime.js','./app-v03.js','./media-runtime.js','./product-availability.js',
 './product-content/manifest.json','./manifest.json'
];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{
 const r=e.request;
 if(r.mode==='navigate'){
  e.respondWith(fetch(r).then(res=>{const copy=res.clone();caches.open(CACHE).then(c=>c.put('./',copy));return res}).catch(()=>caches.match('./')));
  return;
 }
 e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(r.method==='GET'&&res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(r,copy))}return res})));
});
