# S7-M2 Composition Adapter Evidence

Date: 2026-08-25 JST
Worker: M2
Branch: `scaniverse/s7-m2-trainer-memory`
Pinned Msplat: `d620d9c58d270e7de9e34a9d8a85dcf938a5070d`

## Purpose

M1 and M2 both materialize the same pinned Msplat dependency. Their source ownership is disjoint, but each standalone materializer starts from a clean pinned checkout. Running one standalone materializer after the other would therefore erase the first lane's generated source changes.

M1 owns `input_data.hpp`, `input_data.cpp`, and `msplat_api.mm`. M2 owns `metal_tensor.hpp`, `model.hpp`, and `model.cpp`.

The actual M1 materializer also creates an untracked `.scaniverse-m1-revision` marker containing the pinned revision. It is integration metadata, not an additional source patch, but it is part of the real dirty-tree shape that M2 must preserve.

## M2 integration adapter

`scripts/apply_msplat_m2_to_existing.sh <msplat-root>` applies M2 to an already-materialized pinned checkout without reset, clean, clone, or checkout.

It fails closed unless:

1. the target is a Git checkout at the exact pinned revision;
2. none of M2's three owned source files were already modified in either the working tree or index;
3. all pre-existing dirty files remain dirty after M2 application;
4. the only newly changed files are M2's three owned files;
5. both unstaged and staged diffs pass `git diff --check`;
6. the existing M2 memory contract test passes.

The dirty-file inventory is the sorted union of unstaged tracked changes, staged tracked changes, and untracked files. This prevents a staged-only edit from bypassing the M2-owned-file conflict gate and preserves M1's untracked revision marker.

Pre-existing dirty changes in disjoint files are intentionally preserved. This is the required property for composing M1 first and M2 second on one local Msplat tree.

## Composition contract test

`scripts/test_m2_composition_adapter.sh` runs against the exact pinned checkout using temporary Git worktrees.

The positive case now mirrors the actual structural output of `materialize_msplat_memory.sh`:

- `input_data.hpp` as staged-only;
- `input_data.cpp` as unstaged;
- `msplat_api.mm` as staged-only;
- untracked `.scaniverse-m1-revision` containing the exact pin.

It then applies the M2 adapter and requires the dirty inventory to contain exactly those four pre-existing M1 paths plus M2's three owned source files. It also verifies the M1 source marker content, staged state, and revision-marker contents survive unchanged.

The negative case stages a change to M2-owned `model.hpp` and requires the adapter to reject it before patching. This directly covers the staged-only conflict caveat found in the M1 post-acceptance audit.

## Standalone verification

`prepare_msplat_m2.sh` delegates its normal clean-tree preparation to the same adapter and runs the composition contract test first. Therefore repository project generation, Smoke Diagnostic, Native iOS Build, Simulator build, and unsigned iPhone compile exercise both the adapter and its M1-shaped composition test on every non-cached M2 preparation.

## HQ composition contract

Recommended order:

1. materialize the exact pinned Msplat revision once;
2. apply and test M1;
3. confirm the real M1 dirty inventory is its three owned source files plus `.scaniverse-m1-revision`;
4. invoke `apply_msplat_m2_to_existing.sh` on that same tree;
5. verify the combined **source** patch set is exactly the three M1 files plus the three M2 files, while the full dirty inventory additionally retains `.scaniverse-m1-revision`;
6. rerun both M1 and M2 contract tests on the combined tree;
7. point `project.yml` to that single combined tree;
8. preserve SH's independent `project.yml` test-source addition;
9. run full integration CI before Build 5.

The adapter handles staged, unstaged, and untracked composition states. HQ does not need a special "keep the generated tree unstaged" assumption and must not reject the expected M1 revision marker as an unexpected source delta.

This adapter does not merge M1 code into the M2 branch and does not change M1-owned files. HQ remains the only integration owner.
