# HomeCourt同等化｜PARITY_MATRIX v1.0

基準日: 2026-08-22 JST

Status: `MISSING -> PARTIAL -> NEAR_PARITY -> PARITY`

PARITY requires function existence + accuracy + UX + latency/performance + stability/recovery + real-device evidence. A strong row never offsets a missing row.

| ID | Capability | Current | Minimum evidence for PARITY |
|---|---|---|---|
| HC-P001 | iPhone camera-only real-time measurement | MISSING | real-device continuous capture, no external sensor required |
| HC-P002 | player detection/tracking | MISSING | identity continuity across representative movement/occlusion |
| HC-P003 | human pose tracking | MISSING | joint continuity/latency measured on real movement |
| HC-P004 | ball detection/tracking | MISSING | real ball trajectories across speed/color/background conditions |
| HC-P005 | rim / court target recognition | MISSING | stable rim/court localization and confidence/unknown |
| HC-P006 | temporal multi-object fusion | MISSING | synchronized player/ball/rim state without frame-order corruption |
| HC-P007 | shot candidate / arc event | PARTIAL | existing trajectory detector is algorithm-only; requires real detector input and differential evidence |
| HC-P008 | make / miss / unknown | MISSING | real shot confusion matrix; uncertain cases rejected rather than falsely finalized |
| HC-P009 | shooting percentage / accuracy | MISSING | derived from verified make/miss events with session reconciliation |
| HC-P010 | release time | MISSING | defined event boundaries and reference-vs-own error distribution |
| HC-P011 | release angle | MISSING | real-device metric error measured against accepted reference method |
| HC-P012 | shot speed | MISSING | calibrated metric with repeatability and unit definition |
| HC-P013 | shot location / court mapping | MISSING | calibrated court coordinates and reference comparison |
| HC-P014 | shot vertical / jump metric | MISSING | repeatable jump/release vertical measurement and confidence |
| HC-P015 | leg angle / shooting-form metric | MISSING | pose-derived metric with repeatability and unknown handling |
| HC-P016 | shot-type filtering (FT / layup / off-dribble / catch-shoot) | MISSING | classification accuracy on real sessions |
| HC-P017 | dribble event count | MISSING | left/right and normal-speed real dribble detection |
| HC-P018 | crossover / hand-switch recognition | MISSING | labeled real-event precision/recall |
| HC-P019 | dribble speed / handling metrics | MISSING | calibrated timing metric and consistency |
| HC-P020 | ball-handling guided drills | MISSING | playable guided drill with real-time scoring/feedback |
| HC-P021 | agility / reaction drills | MISSING | interactive targets/cones/hurdles-equivalent experience and timing accuracy |
| HC-P022 | vertical jump evaluation | MISSING | guided capture, measurement, result persistence |
| HC-P023 | shuttle / lane agility measurement | MISSING | guided drill, timing/route validation, stable result |
| HC-P024 | body measurements (hand span / wingspan / standing reach where current Reference exposes them) | MISSING | camera-guided measurement with calibration/error evidence |
| HC-P025 | guided drills / challenges | MISSING | start instructions -> live cues -> completion -> score/result |
| HC-P026 | real-time visual/audio feedback | MISSING | measured feedback latency and no contradictory feedback |
| HC-P027 | session start -> measure -> end -> results | MISSING | complete real-device vertical slice |
| HC-P028 | pause / resume | MISSING | no duplicate/lost events across pause boundary |
| HC-P029 | foreground/background/interruption recovery | MISSING | state restoration and safe camera/session recovery |
| HC-P030 | long-session stability | MISSING | extended real-device run with thermal/memory/battery observations |
| HC-P031 | session history / progress | MISSING | persisted history, reopen/readback, trend/progress view |
| HC-P032 | video/evidence recording and review | MISSING | timestamp-aligned replay/evidence usable for QA/user review |
| HC-P033 | skill ratings / progress scoring | MISSING | transparent stable score inputs; accuracy/speed/consistency/difficulty-equivalent coverage |
| HC-P034 | personalized/recommended training flow | MISSING | recommendation logic and repeatable next-session experience |
| HC-P035 | teams / leaderboards / challenge/battle experience | MISSING | core social challenge loop if retained in current major iPhone Reference |
| HC-P036 | multi-player workout separation | MISSING | representative multi-person session and correct attribution |
| HC-P037 | low-light tolerance | MISSING | measured degradation/failure policy |
| HC-P038 | background/venue/服装 variation | MISSING | representative condition matrix with confidence behavior |
| HC-P039 | ball color variation | MISSING | representative colors and unknown/failure behavior |
| HC-P040 | distance / framing / angle variation | MISSING | supported envelope documented and verified |
| HC-P041 | multiple-person edge cases | MISSING | correct target selection/unknown rather than false assignment |
| HC-P042 | confidence / unknown / reject design | MISSING | uncertain inputs do not produce fabricated measurements |
| HC-P043 | latency / FPS | MISSING | end-to-end real-device measurement and target thresholds |
| HC-P044 | thermal / memory / battery | MISSING | extended-run resource evidence |
| HC-P045 | launch-to-measurement speed / operation count | MISSING | timed Reference-vs-own comparison |
| HC-P046 | crash/restart/failure recovery | MISSING | defined recovery paths and persisted-state integrity |

## Current aggregate

- PARITY: 0
- NEAR_PARITY: 0
- PARTIAL: 1
- MISSING: 45

## Reference discoveries added in this bootstrap

Current official/App Store material explicitly markets or documents: real-time jump-shot/crossover tracking, shooting percentage/accuracy/release time/dribble speed/vertical jump, AR live-action drills with audio cues/targets, 100+ drills, full history/skill ratings in HomeCourt Plus, shooting analysis including release angle/speed/vertical/leg angle and shot filtering, agility/vertical/shuttle/lane drills, body measurements used in Global Scout, teams/challenges and multi-player workouts. These remain PARITY rows unless fresh Reference verification proves a feature is no longer present.
