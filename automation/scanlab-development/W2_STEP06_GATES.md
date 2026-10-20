# W2 STEP06

Queue epoch1 and resource lock re-read on 2026-10-20.

ViewerStateTests: replaced historical metric meter expectation with uncalibrated scene unit expectation; corrupted primary must remain unchanged after load.
ViewerSidecarWriteSafetyTests: corrected export materializer test to require no implicit repair write.
ExportAdmissionTests: corresponding preflight test still expects implicit repair and has NOT been updated; native full test remains RED until corrected.

Do not merge, release, or claim CI PASS. Published assets not deleted. Native/DB/Edge/iPhone acceptance NOT_RUN.
