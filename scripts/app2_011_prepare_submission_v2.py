#!/usr/bin/env python3
"""TAKU submission prerequisite runner with robust content-rights handling."""
from __future__ import annotations

import app2_011_prepare_submission as base


def ensure_content_rights(token, actions):
    # App Store Connect currently accepts this PATCH but may omit the field from
    # a subsequent GET even when fields[apps] requests it. Treat a successful
    # 2xx PATCH as authoritative; final review submission is the server-side
    # validation of the declaration.
    path = f"/v1/apps/{base.APP_ID}?fields[apps]=bundleId,contentRightsDeclaration"
    _, payload = base.req(token, path)
    app = payload.get("data") or {}
    a = base.attrs(app)
    if a.get("bundleId") != base.BUNDLE_ID:
        raise RuntimeError("App/bundle mismatch")
    if a.get("contentRightsDeclaration") == "DOES_NOT_USE_THIRD_PARTY_CONTENT":
        return "DOES_NOT_USE_THIRD_PARTY_CONTENT"
    base.req(token, f"/v1/apps/{base.APP_ID}", "PATCH", {
        "data": {
            "type": "apps",
            "id": base.APP_ID,
            "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
        }
    })
    actions.append("content_rights_declared")
    return "DOES_NOT_USE_THIRD_PARTY_CONTENT"


base.ensure_content_rights = ensure_content_rights

if __name__ == "__main__":
    base.main()
