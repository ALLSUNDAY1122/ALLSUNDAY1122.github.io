#!/usr/bin/env python3
"""Target-bound Pitari Build 12 asset bridge. No media or plaintext upload URLs leave CI."""
import base64, hashlib, json, os, re, sys, urllib.error, urllib.request
from datetime import datetime, timezone
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app_store_connect_api import load_private_key, make_token

APP="6795941132"
BUNDLE="jp.allsunday.pitariresize"
VERSION="e0aa7c21-0569-4e59-85e7-3cc3afe65dff"
BUILD="b0821263-a794-467f-baf0-41b386f6f233"
DETAIL="7416f717-4d3b-475d-9c86-7f1f00a34627"
LOC="415714d1-5d12-4f37-87e2-7da943a70518"
IAP="6798713983"
FILES={
 "video":{"type":"appStoreReviewAttachments","file_name":"pitari_app_review_combined_20261104.mp4","size":9266107},
 "screenshot":{"type":"appScreenshots","file_name":"pitari_build12_iphone_screenshot_20261104.png","size":417730,"display":"APP_IPHONE_61"}
}
OLD_FAILED={"e268c8c1-bb46-44e2-8bf0-7163a6367fd0","911e8b77-4d7f-42b2-b441-5c666a1d0826"}
class ApiError(Exception):
 def __init__(self,status,codes):
  self.status=status; self.codes=codes
def call(token,path,method="GET",payload=None):
 assert path.startswith(("/v1/","/v2/")) and method in {"GET","POST","PATCH","DELETE"}
 raw=None if payload is None else json.dumps(payload).encode()
 req=urllib.request.Request("https://api.appstoreconnect.apple.com"+path,data=raw,method=method,headers={"Authorization":"Bearer "+token,"Content-Type":"application/json","Accept":"application/json"})
 try:
  with urllib.request.urlopen(req,timeout=40) as response:
   data=response.read()
   return json.loads(data) if data else {}
 except urllib.error.HTTPError as exc:
  try: errors=json.loads(exc.read()).get("errors",[])
  except Exception: errors=[]
  codes=[str(e.get("code","UNKNOWN"))[:160] for e in errors]
  raise ApiError(exc.code,codes) from None
def rows(p):
 d=p.get("data",[])
 return d if isinstance(d,list) else [d] if isinstance(d,dict) else []
def one(p):
 r=rows(p); assert len(r)==1,"Expected one resource"
 return r[0]
def attrs(r): return r.get("attributes") or {}
def ids(p): return {r["id"] for r in rows(p)}
def rel(typ,id): return {"data":{"type":typ,"id":id}}
def delivery(r): return attrs(r).get("assetDeliveryState") or {}
def sealed(data,pem):
 pub=serialization.load_pem_public_key(pem.encode())
 assert isinstance(pub,rsa.RSAPublicKey) and pub.key_size>=3072,"RSA 3072+ recipient required"
 key=os.urandom(32); nonce=os.urandom(12)
 ciphertext=AESGCM(key).encrypt(nonce,json.dumps(data).encode(),b"pitari-review-v1")
 wrapped=pub.encrypt(key,padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),algorithm=hashes.SHA256(),label=None))
 return {k:base64.b64encode(v).decode() for k,v in {"wrapped_key":wrapped,"nonce":nonce,"ciphertext":ciphertext}.items()}
def preflight(token):
 app=one(call(token,f"/v1/apps/{APP}"))
 assert attrs(app).get("bundleId")==BUNDLE,"App identity mismatch"
 assert VERSION in ids(call(token,f"/v1/apps/{APP}/appStoreVersions?limit=200")),"Version ownership mismatch"
 version=one(call(token,f"/v1/appStoreVersions/{VERSION}"))
 assert attrs(version).get("platform")=="IOS" and attrs(version).get("versionString")=="1.0","Version mismatch"
 selected=one(call(token,f"/v1/appStoreVersions/{VERSION}/build"))
 assert selected["id"]==BUILD and attrs(selected).get("version")=="12","Selected Build 12 required"
 assert attrs(selected).get("processingState")=="VALID" and not attrs(selected).get("expired"),"Build invalid"
 detail=one(call(token,f"/v1/appStoreVersions/{VERSION}/appStoreReviewDetail"))
 assert detail["id"]==DETAIL,"Review detail ownership mismatch"
 assert LOC in ids(call(token,f"/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations")),"Localization ownership mismatch"
 return version,detail
def sets(token):
 return rows(call(token,f"/v1/appStoreVersionLocalizations/{LOC}/appScreenshotSets?limit=100"))
def collections(token):
 out={"video":rows(call(token,f"/v1/appStoreReviewDetails/{DETAIL}/appStoreReviewAttachments?limit=100")),"screenshot":[]}
 for ss in sets(token):
  for s in rows(call(token,f"/v1/appScreenshotSets/{ss['id']}/appScreenshots?limit=100")):
   s["_set_id"]=ss["id"];s["_display"]=attrs(ss).get("screenshotDisplayType");out["screenshot"].append(s)
 return out
def sanitized_asset(r):
 a=attrs(r); d=delivery(r)
 return {"id":r["id"],"type":r["type"],"file_name":a.get("fileName"),"file_size":a.get("fileSize"),"state":d.get("state"),"error_codes":[e.get("code") for e in d.get("errors") or []],"display":r.get("_display")}
def audit(token,version,detail):
 assets=collections(token)
 iap=one(call(token,f"/v2/inAppPurchases/{IAP}"))
 assert attrs(iap).get("productId")=="jp.allsunday.pitariresize.pro.lifetime" and attrs(iap).get("inAppPurchaseType")=="NON_CONSUMABLE","IAP identity mismatch"
 shot=one(call(token,f"/v2/inAppPurchases/{IAP}/appStoreReviewScreenshot"))
 iv=rows(call(token,f"/v2/inAppPurchases/{IAP}/versions?limit=100"))
 a=attrs(detail);notes=a.get("notes") or ""
 return {"app_id":APP,"bundle_id":BUNDLE,"version_id":VERSION,"build_id":BUILD,"app_store_state":attrs(version).get("appStoreState"),"review_notes":{"present":bool(notes),"length":len(notes),"sha256":hashlib.sha256(notes.encode()).hexdigest(),"demo_account_required":a.get("demoAccountRequired"),"contact_present":{k:bool(a.get(k)) for k in ["contactFirstName","contactLastName","contactPhone","contactEmail"]}},"assets":{k:[sanitized_asset(r) for r in v] for k,v in assets.items()},"iap":{"id":IAP,"state":attrs(iap).get("state"),"review_screenshot":sanitized_asset(shot),"versions":[{"id":r["id"],"state":attrs(r).get("state")} for r in iv]},"review_submissions":[{"id":r["id"],"state":attrs(r).get("state")} for r in rows(call(token,f"/v1/reviewSubmissions?filter[app]={APP}&limit=100"))]}
def execute(token,command):
 version,detail=preflight(token);action=command["action"]

 if action=="replace_video_reservation":
  assert command.get("replacement_sha256")=="7e28f053605f255bb6f98b671fdea8bdfeef5190fe34dead3391be12b602731f","Unexpected replacement bytes"
  sealed({},command["recipient_public_key"])
  existing=collections(token)["video"]
  old=[r for r in existing if r["id"]=="825e0bce-5342-4b42-b64d-b58ef8aef900"]
  if old:
   assert len(existing)==1 and attrs(old[0]).get("fileName")=="pitari_app_review_demo_original_20261104.mp4" and delivery(old[0]).get("state")=="COMPLETE","Old attachment target changed"
   call(token,"/v1/appStoreReviewAttachments/825e0bce-5342-4b42-b64d-b58ef8aef900","DELETE")
   assert "825e0bce-5342-4b42-b64d-b58ef8aef900" not in ids(call(token,f"/v1/appStoreReviewDetails/{DETAIL}/appStoreReviewAttachments")),"Old reservation still present"
  next_command=dict(command);next_command["action"]="reserve_assets"
  return execute(token,next_command)
 if action=="save_review_info":
  notes=command.get("notes","")
  assert 0<len(notes)<=4000 and "iOS 27.2" in notes and FILES["video"]["file_name"] in notes,"Incomplete review notes"
  source=one(call(token,"/v1/apps/6794796078"))
  assert attrs(source).get("name")=="仕訳スワイプ","Contact source app mismatch"
  source_versions=[r for r in rows(call(token,"/v1/apps/6794796078/appStoreVersions?limit=200")) if attrs(r).get("versionString")=="1.0" and attrs(r).get("platform")=="IOS"]
  assert len(source_versions)==1,"Ambiguous contact source version"
  source_detail=one(call(token,f"/v1/appStoreVersions/{source_versions[0]['id']}/appStoreReviewDetail"))
  keys=["contactFirstName","contactLastName","contactPhone","contactEmail"]
  contact={k:attrs(source_detail).get(k) for k in keys}
  assert all(isinstance(v,str) and v.strip() for v in contact.values()),"Source contact incomplete"
  payload={**contact,"notes":notes,"demoAccountRequired":False}
  call(token,f"/v1/appStoreReviewDetails/{DETAIL}","PATCH",{"data":{"type":"appStoreReviewDetails","id":DETAIL,"attributes":payload}})
  readback=attrs(one(call(token,f"/v1/appStoreReviewDetails/{DETAIL}")))
  assert all(readback.get(k)==v for k,v in payload.items()),"Review info readback mismatch"
  return {"contact_source_app_id":"6794796078","contact_values_match":True,"contact_fields_present":{k:bool(readback.get(k)) for k in keys},"notes_match":True,"notes_sha256":hashlib.sha256(notes.encode()).hexdigest(),"notes_length":len(notes)}
 if action=="submit_review":
  a=audit(token,version,detail)
  assert command.get("privacy_audit_confirmed") is True,"Privacy declaration audit required"
  assert a["review_notes"]["sha256"]==command.get("expected_notes_sha256") and a["review_notes"]["present"],"Expected saved notes required"
  assert all(a["review_notes"]["contact_present"].values()),"Review contact required"
  assert all(r["state"]=="COMPLETE" for group in a["assets"].values() for r in group),"All reserved assets must be COMPLETE"
  assert any(r["file_name"]==FILES["video"]["file_name"] for r in a["assets"]["video"]),"Combined evidence video required"
  assert any(r["id"]=="4fc00019-511d-850c-800e-088e0d9e8b05" and r["state"]=="COMPLETE" for r in a["assets"]["screenshot"]),"Required screenshot missing"
  assert a["iap"]["review_screenshot"]["state"]=="COMPLETE","IAP review image incomplete"
  assert a["iap"]["state"] in {"READY_TO_SUBMIT","WAITING_FOR_REVIEW","IN_REVIEW","APPROVED"},"IAP not ready"
  submissions=rows(call(token,f"/v1/reviewSubmissions?filter[app]={APP}&limit=100"))
  active=[r for r in submissions if attrs(r).get("state") in {"READY_FOR_REVIEW","WAITING_FOR_REVIEW","IN_REVIEW","UNRESOLVED_ISSUES"}]
  assert len(active)<=1,"Ambiguous active review submission"
  if active:sub=active[0]
  else:sub=one(call(token,"/v1/reviewSubmissions","POST",{"data":{"type":"reviewSubmissions","attributes":{"platform":"IOS"},"relationships":{"app":rel("apps",APP)}}}))
  sid=sub["id"]
  assert attrs(sub).get("state") in {"READY_FOR_REVIEW","WAITING_FOR_REVIEW","IN_REVIEW"},"Existing submission has unresolved issues; do not blindly resubmit"
  iv=[r for r in a["iap"]["versions"] if r["id"]=="ef6394de-91a3-434d-b1da-92246c04c927"]
  assert len(iv)==1,"IAP version mismatch"
  items=rows(call(token,f"/v1/reviewSubmissions/{sid}/items?include=appStoreVersion,inAppPurchaseVersion&limit=100"))
  expected={("appStoreVersion",VERSION),("inAppPurchaseVersion",iv[0]["id"])}
  present=set()
  for item in items:
   found=[]
   for key,value in (item.get("relationships") or {}).items():
    data=value.get("data")
    if isinstance(data,dict):found.append((key,data.get("id")))
   assert len(found)==1 and found[0] in expected,"Unrelated submission item present"
   present.add(found[0])
  if attrs(sub).get("state") in {"WAITING_FOR_REVIEW","IN_REVIEW"}:
   assert expected==present,"Active submission does not contain both intended items"
   return {"submission_id":sid,"submission_complete":a["app_store_state"] in {"WAITING_FOR_REVIEW","IN_REVIEW"},"state":attrs(sub)["state"],"audit":a}
  for key,target in sorted(expected-present):
   typ="appStoreVersions" if key=="appStoreVersion" else "inAppPurchaseVersions"
   call(token,"/v1/reviewSubmissionItems","POST",{"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":rel("reviewSubmissions",sid),key:rel(typ,target)}}})
  call(token,f"/v1/reviewSubmissions/{sid}","PATCH",{"data":{"type":"reviewSubmissions","id":sid,"attributes":{"submitted":True}}})
  sub=one(call(token,f"/v1/reviewSubmissions/{sid}"))
  after=one(call(token,f"/v1/appStoreVersions/{VERSION}"))
  state=attrs(sub).get("state")
  return {"submission_id":sid,"state":state,"app_store_state":attrs(after).get("appStoreState"),"submission_complete":state in {"WAITING_FOR_REVIEW","IN_REVIEW","COMPLETE"} and attrs(after).get("appStoreState") in {"WAITING_FOR_REVIEW","IN_REVIEW","PENDING_DEVELOPER_RELEASE","READY_FOR_SALE"}}

 if action=="audit": return audit(token,version,detail)
 if action=="reserve_assets":
  # Validate recipient before creating any Apple resource.
  sealed({},command["recipient_public_key"])
  existing=collections(token);reserved=[]
  for kind in ["video","screenshot"]:
   f=FILES[kind];matches=[r for r in existing[kind] if attrs(r).get("fileName")==f["file_name"]]
   assert len(matches)<=1,"Ambiguous existing filename"
   if matches:
    resource=matches[0];assert attrs(resource).get("fileSize")==f["size"],"Existing size mismatch"
    resource=one(call(token,f"/v1/{f['type']}/{resource['id']}"))
   else:
    if kind=="video": relationships={"appStoreReviewDetail":rel("appStoreReviewDetails",DETAIL)}
    else:
     matching=[s for s in sets(token) if attrs(s).get("screenshotDisplayType")==f["display"]]
     assert len(matching)<=1,"Ambiguous screenshot set"
     if matching: ss=matching[0]
     else: ss=one(call(token,"/v1/appScreenshotSets","POST",{"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":f["display"]},"relationships":{"appStoreVersionLocalization":rel("appStoreVersionLocalizations",LOC)}}}))
     relationships={"appScreenshotSet":rel("appScreenshotSets",ss["id"])}
    resource=one(call(token,"/v1/"+f["type"],"POST",{"data":{"type":f["type"],"attributes":{"fileName":f["file_name"],"fileSize":f["size"]},"relationships":relationships}}))
   assert delivery(resource).get("state")!="FAILED","Existing asset failed; explicit remediation needed"
   reserved.append({"kind":kind,"resource":resource})
  return {"assets":[{"kind":r["kind"],**sanitized_asset(r["resource"])} for r in reserved],"encrypted_upload_instructions":sealed(reserved,command["recipient_public_key"])}
 if action=="complete_assets":
  existing=collections(token);receipt=[]
  for asset in command["assets"]:
   kind=asset["kind"];f=FILES[kind];assert re.fullmatch(r"[a-f0-9]{32}",asset["md5"]),"Invalid MD5"
   matches=[r for r in existing[kind] if r["id"]==asset["id"] and attrs(r).get("fileName")==f["file_name"] and attrs(r).get("fileSize")==f["size"]]
   assert len(matches)==1,"Asset ownership mismatch"
   r=matches[0]
   if delivery(r).get("state")!="COMPLETE":
    call(token,f"/v1/{f['type']}/{r['id']}","PATCH",{"data":{"type":f["type"],"id":r["id"],"attributes":{"uploaded":True,"sourceFileChecksum":asset["md5"]}}})
   receipt.append(sanitized_asset(one(call(token,f"/v1/{f['type']}/{r['id']}"))))
  return {"assets":receipt}
 if action=="remove_failed_screenshots":
  existing=collections(token)
  assert any(attrs(r).get("fileName")==FILES["screenshot"]["file_name"] and delivery(r).get("state")=="COMPLETE" for r in existing["screenshot"]),"Replacement must be COMPLETE"
  removed=[]
  for r in existing["screenshot"]:
   if r["id"] in OLD_FAILED:
    assert delivery(r).get("state")=="FAILED" and r["_set_id"]=="32b924ca-603f-4003-b61f-46b41a1e469e","Old failed target changed"
    call(token,f"/v1/appScreenshots/{r['id']}","DELETE");removed.append(r["id"])
  return {"removed_failed_ids":removed,"audit":audit(token,version,detail)}
 raise ValueError("Unsupported target-bound action")
def main():
 command=json.loads(Path("automation/pitari-review-command.json").read_text())
 request_id=command["request_id"];assert re.fullmatch(r"[A-Za-z0-9._-]{1,100}",request_id),"Invalid request id"
 out={"request_id":request_id,"checked_at":datetime.now(timezone.utc).isoformat(),"action":command["action"],"app_id":APP}
 key_path,cleanup=load_private_key()
 try:
  token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key_path)
  out["result"]=execute(token,command);out["ok"]=True
 except ApiError as exc:
  out.update(ok=False,error={"http_status":exc.status,"codes":exc.codes})
 except Exception as exc:
  # Never serialize arbitrary exception text, response bodies, tokens or upload URLs.
  out.update(ok=False,error={"type":type(exc).__name__})
 finally:
  if cleanup:cleanup.unlink(missing_ok=True)
 result_path=Path("automation/pitari-review-results")/(request_id+".json")
 result_path.parent.mkdir(parents=True,exist_ok=True);result_path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
 print("Pitari request "+request_id+" result ok="+str(out["ok"])+"; sanitized receipt saved")
 return 0 if out["ok"] else 1
if __name__=="__main__":sys.exit(main())
