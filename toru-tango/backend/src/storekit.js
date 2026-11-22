// Minimal X.509 DER verifier for Apple StoreKit 2 transaction JWS in Workers.
// Trust anchor is Apple's published Apple Root CA - G3 SHA-256 fingerprint.
const ROOT_G3_SHA256 = '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179';
const decoder = new TextDecoder();
function bytesFrom64(input, url = false) {
  if (typeof input !== 'string' || input.length > 20000 || !/^[A-Za-z0-9+/_=-]+$/.test(input)) throw Error('bad base64');
  const s = (url ? input.replace(/-/g, '+').replace(/_/g, '/') : input).replace(/=+$/, '');
  return Uint8Array.from(atob(s.padEnd(Math.ceil(s.length / 4) * 4, '=')), x => x.charCodeAt(0));
}
function derNode(b, at) {
  const start = at, tag = b[at++]; if (tag === undefined) throw Error('bad DER');
  let len = b[at++]; if (len === undefined) throw Error('bad DER');
  if (len & 128) {
    const size = len & 127; if (!size || size > 4) throw Error('bad DER length');
    len = 0; for (let i = 0; i < size; i++) len = len * 256 + b[at++];
  }
  const from = at, end = at + len;
  if (end > b.length || !Number.isFinite(end)) throw Error('truncated DER');
  return {tag,start,from,end};
}
function children(b, n) {
  const out = []; for (let p=n.from; p<n.end;) { const c=derNode(b,p);out.push(c);p=c.end; }
  if (out.length > 100) throw Error('DER nesting'); return out;
}
function raw(b,n) { return b.slice(n.start,n.end); }
function parseCert(data) {
  const outer=children(data,derNode(data,0));
  if (outer.length !== 3) throw Error('bad certificate');
  const tbs=children(data,outer[0]);
  const versionOffset=tbs[0].tag === 0xa0 ? 1 : 0;
  const issuer=tbs[2+versionOffset], validity=tbs[3+versionOffset],
    subject=tbs[4+versionOffset], spki=tbs[5+versionOffset];
  const dates=children(data,validity).map(n=>{
    const s=decoder.decode(data.slice(n.from,n.end));
    if (n.tag===0x17) return Date.parse((Number(s.slice(0,2))>=50?'19':'20')+s.slice(0,2)+'-'+s.slice(2,4)+'-'+s.slice(4,6)+'T'+s.slice(6,8)+':'+s.slice(8,10)+':'+s.slice(10,12)+'Z');
    if (n.tag===0x18) return Date.parse(s.slice(0,4)+'-'+s.slice(4,6)+'-'+s.slice(6,8)+'T'+s.slice(8,10)+':'+s.slice(10,12)+':'+s.slice(12,14)+'Z');
    throw Error('bad certificate validity');
  });
  const sig=children(data,outer[1])[0];
  const oid=Array.from(data.slice(sig.from,sig.end)).join(',');
  return {data, tbs:raw(data,outer[0]), issuer:raw(data,issuer), subject:raw(data,subject),
    spki:raw(data,spki), dates, sigOid:oid, signature:data.slice(outer[2].from+1,outer[2].end)};
}
function same(a,b) {return a.length===b.length && a.every((x,i)=>x===b[i]);}
function ecdsaRaw(der,width) {
  const nodes=children(der,derNode(der,0));if(nodes.length!==2)throw Error('bad ECDSA');
  const out=new Uint8Array(width*2);
  for(let i=0;i<2;i++){let a=der.slice(nodes[i].from,nodes[i].end);
    while(a.length>width && a[0]===0)a=a.slice(1);
    if(a.length>width)throw Error('large ECDSA');out.set(a,width*(i+1)-a.length);}
  return out;
}
async function verifyCert(child, parent) {
  if(!same(child.issuer,parent.subject))throw Error('issuer mismatch');
  const hash = child.sigOid === '42,134,72,206,61,4,3,2'?'SHA-256':
    child.sigOid === '42,134,72,206,61,4,3,3'?'SHA-384':null;
  if(!hash)throw Error('unsupported certificate signature');
  const curve=parent.spki.length>150?'P-384':'P-256';
  const key=await crypto.subtle.importKey('spki',parent.spki,{name:'ECDSA',namedCurve:curve},false,['verify']);
  const ok=await crypto.subtle.verify({name:'ECDSA',hash},key,ecdsaRaw(child.signature,curve==='P-384'?48:32),child.tbs);
  if(!ok)throw Error('untrusted certificate');
}
export async function verifyStoreKitTransaction(jws, now = Date.now()) {
  if(typeof jws!=='string'||jws.length>24000)throw Error('invalid JWS');
  const parts=jws.split('.');if(parts.length!==3)throw Error('invalid JWS');
  const header=JSON.parse(decoder.decode(bytesFrom64(parts[0],true)));
  if(header.alg!=='ES256'||!Array.isArray(header.x5c)||header.x5c.length<2||header.x5c.length>5)throw Error('invalid header');
  const certs=header.x5c.map(s=>parseCert(bytesFrom64(s)));
  const root=certs.at(-1);
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',root.data)),x=>x.toString(16).padStart(2,'0')).join('');
  if(digest!==ROOT_G3_SHA256)throw Error('untrusted root');
  for(const c of certs)if(c.dates.some(d=>!Number.isFinite(d))||now<c.dates[0]||now>c.dates[1])throw Error('expired certificate');
  for(let i=0;i<certs.length-1;i++)await verifyCert(certs[i],certs[i+1]);
  await verifyCert(root,root);
  const key=await crypto.subtle.importKey('spki',certs[0].spki,{name:'ECDSA',namedCurve:'P-256'},false,['verify']);
  const signature=bytesFrom64(parts[2],true);
  if(signature.length!==64||!await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},key,signature,new TextEncoder().encode(parts[0]+'.'+parts[1])))throw Error('invalid JWS signature');
  const payload=JSON.parse(decoder.decode(bytesFrom64(parts[1],true)));
  const limits={'com.allsunday1122.torutango.pro.monthly50':50,'com.allsunday1122.torutango.pro.monthly100':100};
  if(payload.bundleId!=='com.allsunday1122.torutango'||!Object.hasOwn(limits,payload.productId)||
    !['Sandbox','Production'].includes(payload.environment)||
    !payload.originalTransactionId||!Number.isFinite(Number(payload.purchaseDate))||
    !Number.isFinite(Number(payload.expiresDate))||Number(payload.purchaseDate)>=Number(payload.expiresDate)||
    Number(payload.expiresDate)<=now||payload.revocationDate!=null||payload.inAppOwnershipType==='FAMILY_SHARED')
    throw Error('inactive transaction');
  return {originalTransactionId:String(payload.originalTransactionId),
    purchaseDate:Number(payload.purchaseDate),expiresDate:Number(payload.expiresDate),
    productId:payload.productId,limit:limits[payload.productId],
    tier:limits[payload.productId]===100?'standard':'light'};
}
