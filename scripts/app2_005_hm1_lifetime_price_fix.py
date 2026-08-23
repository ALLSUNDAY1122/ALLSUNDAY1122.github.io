#!/usr/bin/env python3
import json, os, traceback
from pathlib import Path
import app2_005_hm1_iap_bootstrap as b
from app_store_connect_api import load_private_key, make_token

OUT = Path("automation/app2-005-hm1-price-fix-result.json")

def write(payload):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False))

def current_jpn_price(token, iid):
    _, payload = b.req(token, f"/v1/inAppPurchasePriceSchedules/{iid}/manualPrices?filter[territory]=JPN&include=inAppPurchasePricePoint&fields[inAppPurchasePricePoints]=customerPrice&limit=50")
    points = {x.get("id"): x for x in payload.get("included", []) if x.get("type") == "inAppPurchasePricePoints"}
    for row in b.rows(payload):
        attrs = row.get("attributes", {})
        if attrs.get("startDate") is None and attrs.get("endDate") is None:
            point_id = ((row.get("relationships", {}).get("inAppPurchasePricePoint", {}).get("data") or {}).get("id"))
            point = points.get(point_id, {})
            return b.dec(point.get("attributes", {}).get("customerPrice")), point_id
    return b.Decimal("-1"), None

def main():
    cleanup = None
    actions = []
    try:
        key_path, cleanup = load_private_key()
        token = make_token(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], key_path)
        _, app = b.req(token, f"/v1/apps/{b.APP_ID}")
        actual_bundle = app["data"].get("attributes", {}).get("bundleId")
        if actual_bundle != b.BUNDLE_ID:
            raise RuntimeError(f"Bundle mismatch: {actual_bundle}")

        _, listing = b.req(token, f"/v1/apps/{b.APP_ID}/inAppPurchasesV2?limit=200")
        item = b.by_product(b.rows(listing), b.LIFETIME_ID)
        if item is None:
            raise RuntimeError("Lifetime product does not exist")
        iid = item["id"]
        before, _ = current_jpn_price(token, iid)

        if before != b.LIFETIME_PRICE:
            _, points = b.req(token, f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]=JPN&fields[inAppPurchasePricePoints]=customerPrice,territory&include=territory&limit=8000")
            point = next((x for x in b.rows(points) if b.dec(x.get("attributes", {}).get("customerPrice")) == b.LIFETIME_PRICE), None)
            if point is None:
                raise RuntimeError("JPN 800 lifetime price point not found")
            local_id = "${app2-005-hm1-lifetime-800-jpn}"
            payload = {
                "data": {
                    "type": "inAppPurchasePriceSchedules",
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                        "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
                        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": local_id}]},
                    },
                },
                "included": [{
                    "type": "inAppPurchasePrices",
                    "id": local_id,
                    "attributes": {"startDate": None},
                    "relationships": {
                        "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}},
                        "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}},
                    },
                }],
            }
            b.req(token, "/v1/inAppPurchasePriceSchedules", "POST", payload)
            actions.append("changed_lifetime_jpn_price_to_800")

        after, _ = current_jpn_price(token, iid)
        if after != b.LIFETIME_PRICE:
            raise RuntimeError(f"Lifetime JPN price read-back mismatch: {after}")
        write({"task_id":"APP2-005","product_id":b.LIFETIME_ID,"before_jpn":str(before),"after_jpn":str(after),"actions":actions,"ok":True})
    except Exception as exc:
        write({"task_id":"APP2-005","product_id":b.LIFETIME_ID,"actions":actions,"ok":False,"error":str(exc),"traceback_tail":traceback.format_exc()[-4000:]})
        raise
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
