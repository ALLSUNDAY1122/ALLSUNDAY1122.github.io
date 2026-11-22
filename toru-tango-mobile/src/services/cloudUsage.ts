import { useSyncExternalStore } from 'react';
import { getAnonymousId } from './anonymousId';
import { getTransactionJws } from './iap';

export type CloudUsage = { used:number; limit:number; tier:string };
type UsageSnapshot = { usage:CloudUsage|null; status:'loading'|'ready'|'error' };
let current:UsageSnapshot = {usage:null,status:'loading'};
const listeners=new Set<()=>void>();
let refreshVersion=0;
function publish(snapshot:UsageSnapshot) {
  current=snapshot;
  for(const fn of listeners)fn();
}
function subscribe(listener:()=>void) {listeners.add(listener);return ()=>{listeners.delete(listener);};}
function snapshot() {return current;}

export function formatCloudUsage(usage:CloudUsage|null):string {
  if(!usage)return '利用状況を確認中…';
  return `今月 ${usage.used}/${usage.limit}回（${usage.tier==='free'?'無料':'有料'}）`;
}
export function isCloudUsageLimited(usage:CloudUsage|null) {
  return Boolean(usage&&usage.used>=usage.limit);
}
export function useCloudUsage() {
  return useSyncExternalStore(subscribe,snapshot,snapshot);
}
function normalizeUsage(input:unknown):CloudUsage|null {
  if(!input||typeof input!=='object')return null;
  const u=input as Record<string,unknown>;
  const used=Number(u.used),limit=Number(u.limit);
  if(!Number.isFinite(used)||!Number.isFinite(limit)||used<0||limit<=0)return null;
  if(typeof u.tier!=='string')return null;
  return {used,limit,tier:u.tier};
}
// Used for /generate's successful usageLimit, which is authoritative for that response.
export function updateCloudUsageFromResponse(input:unknown) {
  const usage=normalizeUsage(input);
  if(usage){
    refreshVersion++;
    publish({usage,status:'ready'});
  }
}
export async function refreshCloudUsage():Promise<void> {
  const version=++refreshVersion;
  try {
    const base=process.env.EXPO_PUBLIC_AI_API_URL?.trim()||'';
    if(!base.startsWith('https://'))throw new Error('AI_API_NOT_CONFIGURED');
    const url=base.replace(/\/generate\/?$/,'/usage');
    const [anonymousId,jws]=await Promise.all([getAnonymousId(),getTransactionJws()]);
    const response=await fetch(url,{
      method:'POST',
      headers:{'X-Toru-Tango-Anonymous-Id':anonymousId,
        ...(jws?{'X-Toru-Tango-Transaction-JWS':jws}:{})}
    });
    if(!response.ok)throw new Error('usage fetch failed');
    const usage=normalizeUsage(await response.json());
    if(!usage)throw new Error('usage invalid');
    if(version===refreshVersion)publish({usage,status:'ready'});
  }catch {
    if(version===refreshVersion)publish({usage:current.usage,status:'error'});
  }
}
