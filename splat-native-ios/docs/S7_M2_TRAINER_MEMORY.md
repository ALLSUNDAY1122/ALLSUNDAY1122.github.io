# S7-M2 Trainer / Densification Peak Memory Evidence

Date: 2026-08-25 JST
Worker: M2
Branch: `scaniverse/s7-m2-trainer-memory`
Baseline: `42e34fb0a88be264a863666cce68081293cfc4cd`
Pinned msplat upstream: `Voxelio-app/msplat@d620d9c58d270e7de9e34a9d8a85dcf938a5070d`

## Scope

This change only targets Msplat trainer-side GPU-buffer ownership, optimizer/capacity backing storage, and densification scratch lifetime. It does not change Scaniverse quality semantics, capture input quality, the app resource guard, the Gaussian cap, training schedule, SH degree, or output serialization.

The application remains responsible for its existing reconstruction policy (`standardIterations = 7_000`) and SH3 path. M2 does not claim physical-device parity or that the Build 4 OOM/hang is solved; HQ owns the Build 5 physical gate.

## Source-grounded allocation accounting

At SH degree 3 there are 16 SH bases. `featuresRest` therefore stores `(16 - 1) * 3 = 45` Float32 values per Gaussian.

Persistent parameter values per capacity Gaussian:

- means: 3 floats
- scales: 3 floats
- quats: 4 floats
- featuresDc: 3 floats
- featuresRest: 45 floats
- opacities: 1 float
- total: 59 floats = 236 bytes

Adam keeps two full-size Float32 moment tensors for the same six groups:

- parameters: 236 B / capacity Gaussian
- exp_avg + exp_avg_sq: 472 B / capacity Gaussian
- persistent trainer backing subtotal: 708 B / capacity Gaussian

Before M2, `setupOptimizers()` reserved `4 * N` capacity and also kept all densification scratch resident for the whole training run. The SH3 capacity-backed subtotal was:

- parameter + Adam backing: `708 * 4 = 2,832 B / active Gaussian`
- six Int32 densify arrays at `4N`: `96 B / active Gaussian`
- compact scratch at `4N * 45 floats`: `720 B / active Gaussian`
- split random samples at `4N * 3 floats`: `48 B / active Gaussian`
- old steady subtotal: `3,696 B / active Gaussian` (block-total rounding excluded)

M2 changes the initial capacity to the densifier's documented `3N` worst case and removes densification scratch from steady state:

- new steady subtotal: `708 * 3 = 2,124 B / active Gaussian`
- source-model reduction versus the old capacity-backed steady subtotal: about 42.5%

Densification scratch is now allocated only at the logical sizes actually consumed by the GPU pipeline:

- split/dup flag + prefix arrays: four Int32 arrays at `N` = 16 B / active Gaussian
- keep flag + prefix arrays: two Int32 arrays at `3N` = 24 B / active Gaussian
- compact scratch: `3N * 45 floats` = 540 B / active Gaussian
- random samples: `[2N, 3]` = 24 B / active Gaussian
- exact scratch subtotal: about 604 B / active Gaussian, excluding the negligible block-total rounding
- new densification subtotal at a 3N backing capacity: `2,124 + 604 = 2,728 B / active Gaussian`, about 26.2% below the old steady subtotal

These figures are source-model sub-totals, not whole-process measurements. Renderer/image caches, Metal driver allocations, input images, Swift objects, and process overhead are excluded.

For scale only: if an active population happened to equal the Golden final count of 259,243 Gaussians, the modeled old capacity-backed steady subtotal would be about 913.8 MiB; the new steady subtotal would be about 525.1 MiB and the new densification subtotal about 674.5 MiB. Golden's final Gaussian count is not asserted to equal trainer initialization or every densification population.

## Root-cause correction: MTensor ownership

The pinned `MTensor` implementation retained an `MTLBuffer` in the GPU constructor but had no destructor or custom copy/move ownership. `view()` copied the raw retained pointer without retaining it, while `reset()` unconditionally called `CFRelease`. That made two failure modes possible:

1. assigning a new GPU tensor over an owning tensor could overwrite the old retained pointer without releasing the old buffer;
2. resetting a view could release a buffer the view did not own.

M2 changes the internal buffer handle to `std::shared_ptr<void>` with a `CFRelease` custom deleter created by the Objective-C++ GPU constructor. Views share the same control block and remain zero-copy. Normal assignment/reset/destruction therefore releases old GPU storage exactly when the last tensor/view reference disappears.

This also fixes replacement lifetime in reusable Msplat caches, not just `Model::ensureCapacity()`.

## Capacity-growth lifecycle

Before M2, `ensureCapacity()` used `max(needed, 2 * oldCapacity)`. During replacement, all active parameter/Adam views continued to reference the old backing buffers, so a correct shared-ownership implementation alone would still keep the entire old capacity alive until `refreshViews()`.

M2 therefore:

1. synchronizes outstanding Msplat GPU work at a growth boundary;
2. releases any transient densification scratch;
3. detaches parameter/Adam capacity views;
4. grows one backing tensor at a time, allowing each old buffer to die immediately after its replacement copy;
5. uses `max(needed, oldCapacity + 50%)` rather than an unconditional 2x growth;
6. recreates zero-copy active views after all backing buffers are ready.

The densifier still receives a capacity satisfying its own `3 * N <= buf_capacity` assertion. No Gaussian is dropped and no optimizer state is reset by this policy change.

## Densification scratch lifecycle

`msplat_densify()` performs classify → grow → cull → compact and synchronizes its command buffer before it reads and returns `new_count`. Consequently scratch buffers are no longer needed when the function returns.

M2 allocates scratch immediately before densification and releases it immediately after `msplat_densify()` returns. The scratch dimensions follow the pinned implementation's actual dispatch/indexing contract, including the Metal split kernel's documented `[2*N, 3]` random-sample input.

## Reproducible dependency preparation

`project.yml` now points Msplat at `.generated/msplat-m2`. XcodeGen runs `scripts/prepare_msplat_m2.sh` before project generation. The script:

1. fetches exactly `d620d9c58d270e7de9e34a9d8a85dcf938a5070d`;
2. verifies `HEAD` equals that revision;
3. applies `scripts/apply_msplat_m2_patch.py`, whose replacements must each match the pinned source exactly once;
4. rejects any changed file outside the three owned Msplat trainer files;
5. runs `git diff --check`;
6. runs `scripts/test_m2_msplat_memory_patch.py`.

This avoids silently tracking a moving upstream branch while keeping the upstream dependency source auditable.

## Acceptance evidence and remaining gate

Automated acceptance requires:

- patcher succeeds against the pinned upstream revision;
- changed-file allowlist is exactly `metal_tensor.hpp`, `model.hpp`, and `model.cpp`;
- static M2 memory contract passes;
- existing XcodeGen / SwiftPM / simulator tests / Release device compile pass in the repository GitHub Actions workflow.

Physical peak RSS/GPU-memory improvement, real-device completion, thermal behavior, output quality, Gaussian count distribution, and Golden visual/geometry comparison remain HQ/device evidence. M2 must not promote this work to full parity from CI alone.
