# S7-M2 Composition Adapter Evidence

Date: 2026-08-25 JST
Worker: M2
Branch: `scaniverse/s7-m2-trainer-memory`
Pinned Msplat: `d620d9c58d270e7de9e34a9d8a85dcf938a5070d`

## Purpose

M1 and M2 both materialize the same pinned Msplat dependency. Their source ownership is disjoint, but each standalone materializer starts from a clean pinned checkout. Running one standalone materializer after the other would therefore erase the first lane's generated source changes.

M1 owns `input_data.hpp`, `input_data.cpp`, and `msplat_api.mm`. M2 owns `metal_tensor.hpp`, `model.hpp`, and `model.cpp`.

## M2 integration adapter

`scripts/apply_msplat_m2_to_existing.sh <msplat-root>` applies M2 to an already-materialized pinned checkout without reset, clean, clone, or checkout.

It fails closed unless:

1. the target is a Git checkout at the exact pinned revision;
2. none of M2's three owned source files were already modified;
3. all pre-existing dirty files remain dirty after M2 application;
4. the only newly changed files are M2's three owned files;
5. `git diff --check` passes;
6. the existing M2 memory contract test passes.

Pre-existing dirty changes in disjoint files are intentionally preserved. This is the required property for composing M1 first and M2 second on one local Msplat tree.

## Standalone verification

`prepare_msplat_m2.sh` now delegates its normal clean-tree preparation to the same adapter. Therefore the repository's existing project generation, Smoke Diagnostic, Native iOS Build, Simulator build, and unsigned iPhone compile exercise the composition adapter on every M2 CI run rather than leaving it as an untested HQ-only helper.

## HQ composition contract

Recommended order:

1. materialize the exact pinned Msplat revision once;
2. apply and test M1;
3. invoke `apply_msplat_m2_to_existing.sh` on that same tree;
4. verify the combined dirty set is exactly the three M1 files plus the three M2 files;
5. point `project.yml` to that single combined tree;
6. preserve SH's independent `project.yml` test-source addition;
7. run full integration CI before Build 5.

This adapter does not merge M1 code into the M2 branch and does not change M1-owned files. HQ remains the only integration owner.
