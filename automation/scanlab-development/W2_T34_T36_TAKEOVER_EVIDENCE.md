# T34–T36 Worker2 takeover — 2026-10-20

Task SCANLAB-W1-001: owner WORKER_2, epoch2 token SCANLAB-W1-001-a2-W2-20261020; lock scanlab:native-capture-reconstruction-export epoch2 re-read remotely. Dedicated PR #5622, not merged. Baseline HEAD a050e1fd78deb8094178242c4515aeb2819cb64a carried HQ's Mesh durability static fix (do not duplicate).

Baseline Native CI 39367475853 SUCCESS; XCTest 245, 0 failures verified from build log. Source audit found MeshCapture generation guard was only applied to the asynchronous completion, *after* JPEG disk write. Queued old writes could still reach disk after reset. Commit 36cc862ec1d9915d75adb89412fbdd560c8a37e7 adds NSLock-protected MeshFrameWriteFence rotate at both resets and gates worker JPEG write through performIfCurrent. Commit af25f5cccf8fee74aac4c8476a73a972ca0e1e6d updates static Mesh durability contract to require fence rotation before project detachment and queued writer fencing. Source and test readback verified.

Latest new Native iOS run 39369715024 pending at report creation; no PASS claim for new commits. Remaining: live lease/reset race tests, RAW/depth and export nondestruction under fault injection, physical device L4, HQ review. No merge, TestFlight upload or App Review.
