#!/usr/bin/env python3
"""Fail closed when a selected release build predates accepted product changes.

Usage:
  python3 scripts/release_provenance_gate.py --build-sha <sha> --path apps/foo --path ios/foo

This gate intentionally does not query ASC/Codemagic. Platform readback must first resolve
an exact source commit SHA for the selected binary, then pass it here.
"""
from __future__ import annotations
import argparse, subprocess, sys

p=argparse.ArgumentParser()
p.add_argument('--build-sha', required=True)
p.add_argument('--head', default='HEAD')
p.add_argument('--path', action='append', required=True, dest='paths')
a=p.parse_args()

def git(*args:str)->str:
    r=subprocess.run(['git',*args],text=True,capture_output=True)
    if r.returncode:
        print(r.stderr.strip(),file=sys.stderr)
        raise SystemExit(r.returncode)
    return r.stdout.strip()

# Exact binary provenance must resolve to a repository commit.
try: build=git('rev-parse','--verify',f'{a.build_sha}^{{commit}}')
except SystemExit:
    raise SystemExit(f'RELEASE PROVENANCE GATE: FAIL unknown build source commit {a.build_sha}')
head=git('rev-parse','--verify',f'{a.head}^{{commit}}')

# A build from another/unrelated history cannot prove current product inclusion.
r=subprocess.run(['git','merge-base','--is-ancestor',build,head])
if r.returncode != 0:
    raise SystemExit(f'RELEASE PROVENANCE GATE: FAIL build commit {build} is not an ancestor of {head}')

cmd=['diff','--name-only',f'{build}..{head}','--',*a.paths]
changed=[x for x in git(*cmd).splitlines() if x.strip()]
if changed:
    print('RELEASE PROVENANCE GATE: FAIL selected binary predates product deltas')
    print(f'build_sha={build}')
    print(f'head_sha={head}')
    print('product_paths='+','.join(a.paths))
    for x in changed: print('- '+x)
    raise SystemExit(1)

print('RELEASE PROVENANCE GATE: PASS')
print(f'build_sha={build}')
print(f'head_sha={head}')
print('product_paths='+','.join(a.paths))
