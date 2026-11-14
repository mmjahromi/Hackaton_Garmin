# RaceForge Avatar — milestone 2 delivery

SDK **9.1.0**, API **5.2**, compiler **fenix7pro_sim**, runner **fenix7pro**.
The generated application structure and manifest permissions are preserved.
This is an offline synthetic demonstration and an embeddable presentation component.
No teammate code, sensors, session rules, haptics, storage or network were added.

## What changed

The original thin limbs and static expressions were replaced by original,
outlined native artwork with connected joints, shaded athletic clothing, a race
bib, orange shoes, larger eyes and a running-start crouch. Procedural artwork
was chosen over sprites to share joint geometry across expressions and widget
sizes without storing a separate image for every combination. No external art
or sprite assets are required.

Running/walking use four retained joint poses, opposing arms, head/torso bob,
breathing mouth shapes, expanding puffs and intermittent sweat. Strong flushing
is an expressive metaphor enabled by sustained effort context plus EASE_OFF,
never a diagnosis. Celebration bounces briefly then holds. The view publishes
each completed screen from one retained drawing surface rather than exposing
the intermediate drawing commands. There is no frame history.

Animation updates at 4 Hz. Elapsed playback time drives frames; delayed callbacks
do not accumulate a queue of frames. Hide, freeze and static mode stop the timer.
The final celebration stops the timer after 2.4 seconds. START restarts a completed
replay. No 6 Hz or physical MIP smoothness claim is made.

## Controls and scenarios

| Control | Behavior |
| --- | --- |
| START, upper right | Next scene; wraps to beginning |
| UP | Easy replay → tempo replay → six static regression poses |
| DOWN | Freeze/resume both scene and animation time; footer says HOLD |
| Hold MENU | Native menu for modes and pause/resume |
| BACK | Normal Garmin root-view exit; BACK from menu returns to demo |

The top badge always says DEMO. All HR and speed inputs in this app are synthetic.
Top text names the workout, teal text shows HR/pace, bottom text shows the action.
Footer E/T/S identifies easy/tempo/static mode and the current scene.

Each replay scene lasts 8 seconds. The easy script has ten scenes: starting,
comfortable 130 bpm, a single high-effort example at 160 with RUN_EASY unchanged,
sustained 160 with EASE_OFF, sustained 180 with EASE_OFF and a flushed expression,
130 with WALK, recovery, ready-to-run, HR unavailable, completion. Tempo has five:
130 below target with explicit permission to build effort, 155 entering target,
160 happy in target, 180 with EASE_OFF, completion. These are visual storyboards,
not a reimplementation of PacePilot's 180-second rule-engine replay.

Illustrative ranges are configurable in `RaceForgeAvatarWorkoutContext`:
easy 120–145 and tempo 155–175 bpm. `setDemoEffort()` only classifies presentation
metadata; it never returns advice. Live callers must use the existing coach's
interpretation. Below-target tempo says BUILD EFFORT only when the separate
`allowBuildEffort` presentation permission is true and advice remains RUN_EASY.
WALK, EASE_OFF, lifecycle, unavailable HR and resume restrictions take priority.

## Build and reproduce

```sh
bash scripts/build.sh /absolute/path/to/developer_key
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
"$sdk_dir/bin/monkeydo" bin/RaceForge.prg fenix7pro

# Compiles and runs all tests; evaluates the actual SDK test summary.
bash scripts/test.sh /absolute/path/to/developer_key
```

The signing key remains outside the project and is ignored by Git. The script
rejects any compiler version other than 9.1.0. Normal and test builds pass with
only the two original shell warnings: no language-specific resources declared,
and the generated 24 px launcher icon scaled to 40 px. No unsupported-API or
duplicate-declaration warnings remain. `_sim` is only for compilation.

## Verification report — November 14, 2026

Local raw build/test logs are intentionally excluded from this contribution.
Run the scripts below to regenerate them under ignored `bin/`. Current verification
results after relocation are recorded in `README.md`.

| Test | Expected | Actual / result |
| --- | --- | --- |
| avatarDemoCycle | Original six static states and wraparound preserved | Three cycles rendered — PASS |
| avatarStartDelegate | START callbacks and navigation lifecycle remain safe | 18 callbacks, hide/show — PASS |
| avatarAnimationFrames | Four timed frames, puffs/sweat, start progression, final hold | Expected frame/effect fields and native rendering — PASS |
| avatarTimerLifecycle | Idempotent show/hide; pause/static stops timers | 20 cycles, hidden callbacks and mode switches — PASS |
| avatarWorkoutAndCoachAuthority | Same HR differs by workout; advice/resume authoritative | Easy/tempo 160, configurable ranges, no manufactured WALK — PASS |
| avatarUnavailableAndLifecycle | Neutral missing/stale/not-ready HR; lifecycle priority | All invalid statuses, COMPLETE/PAUSED precedence, STILL and source key configuration — PASS |
| avatarSpeedAndPlayback | Bounded nonlinear cadence; no running when still; replay freeze | Optional/extreme speed, paused lifecycle, delayed time and final scene — PASS |
| avatarAllScenesAndCircularUi | Every scene fits circle and renders in an offset widget | Native text metrics, footer spacing, mode badge and two renderer sizes — PASS |
| avatarRenderingBudget | Repeated rendering does not grow retained VM memory | 600 effort renders, 38,520 → 38,520 bytes — PASS |
| Normal/test compilation | SDK 9.1.0 on exact target | BUILD SUCCESSFUL — PASS |
| Graphical simulator evidence | Inspect actual rendered character and poses | Screenshots and 78-second sampled replay captured |
| Physical watch / manual physical buttons | Validate actual hardware and button interaction | NOT RUN |
| macOS automated key/menu input | Drive actual simulator buttons | NOT RUN; Accessibility denied; delegate paths tested in VM |
| On-device smoothness, tearing and battery use | Judge actual MIP performance | NOT RUN; simulator screenshots/tests do not establish this |

Final simulator summary: **9 passed, 0 failed, 0 errors**. Garmin's runner returns
exit code 1 even with this passing summary; `scripts/test.sh` validates the summary
and reports success only when every reported test passed.

The last 600-render stress run took 18,589 ms (about 31 ms per character render).
Earlier runs varied from about 21–81 ms depending on simulator/window state.
These are host-simulator measurements, not hardware frame timing. The memory
figure is retained Monkey C VM usage with the test bitmap; it does not prove
total native graphics allocation or battery cost. The standalone view keeps one
bounded 260 × 260 surface and releases it on hide. Its size is below the installed
profile's 786,432-byte watch-app limit, but hardware validation remains separate.

Actual screenshot review caught an ellipse API error (Garmin uses centers/radii)
and incomplete redraw captures. The ellipse helper was corrected and the view
now draws into a retained surface before copying the completed frame. The full
suite passed again afterward. Some window captures omit parts of gray captions;
manual on-screen flicker/legibility review remains advisable rather than claiming
flawless smoothness from automated evidence.

Evidence: `evidence/m2-easy-replay.mp4` (312 window screenshots sampled at 4 fps,
78 seconds, resized for sharing), plus running, effort, ready and complete PNGs.
The video records the actual simulator; it is not a generated animation. Tempo
and static scenarios are exercised by the VM tests, not a separate graphical
recording. There is no physical-device recording.

## PacePilot integration handoff

Transfer these five files, with their `RaceForgeAvatar*` class names intact:

- `source/AvatarModel.mc`
- `source/AvatarRenderer.mc`
- `source/AvatarAnimator.mc`
- `source/AvatarAdapter.mc`
- `source/AvatarWorkoutContext.mc`

Do not transfer App/View/delegates, replay controller, tests or native demo menu.
No image resources are needed. The renderer draws only the character within
`draw(dc, model, left, top, width, height)` and does not clear the widget or
request an update. It resets the Dc clip to full size and pen width to 1; the
parent must reapply its own clip/colors/pen. The retained full-screen surface is
standalone View code, not part of the renderer or a required PacePilot dependency.

Normal adapter call (valid Monkey C call shape):

```text
// Retain these objects in the teammate's existing view/controller.
adapter  = new RaceForgeAvatarAdapter();
animator = new RaceForgeAvatarAnimator();
renderer = new RaceForgeAvatarRenderer();

// On snapshot changes, using the actual frozen dictionaries:
model = adapter.fromPacePilot(features, decision, lifecycle, workoutType, 0);

// Within the parent's existing onUpdate only:
animator.apply(model, elapsedAnimationTimeMs);
parent clears its widget background;
renderer.draw(dc, model, left, top, width, height);
parent draws the canonical instruction and model.modeText;
```

The parent owns redraw frequency, lifecycle, navigation and a monotonic active
animation clock. Freeze that clock when paused/hidden. Retain animation time
across ordinary HR snapshots; reset on an actual visual-state/decision transition.
The adapter preserves `decisionId`, `reason`, `advice` and `canResumeRun`.
`pose` is the legacy regression field; `visualState` and `motion` drive new art.

`fromPacePilot()` uses no live HR thresholds. For richer effort expressions, pass
an agreed `RaceForgeAvatarWorkoutContext` to `fromContext()` with an effort band
and sustained/permission flags supplied by the existing coach. Do not call the
DEMO range classifier for live coaching or infer a physiological condition.

**Current team contract inspection:** `pacepilot-app/source/Features.mc` uses
`:hr` and `:speed` source-status keys, matching the adapter defaults. The advice,
reason, decisionId and canResumeRun fields in `CoachEngine.mc` also match.
Absent/unknown HR status fails closed to HR UNAVAILABLE. Before embedding, agree
widget bounds, workout-context ownership and animation-clock reset semantics
with UI owner C. No teammate files are changed by this standalone contribution.

Speed is optional, normalized in m/s. SDK 9.1.0's installed API reference confirms
`Activity.Info.currentSpeed` and `Position.Info.speed` as nullable Float m/s fields;
PacePilot must acquire/normalize them. No sensor/GPS API is called by this module.
The animator saturates its nonlinear speed mapping; unavailable/stale speed uses
a state default and STILL overrides the last speed. Visual cadence is never
claimed to equal the athlete's actual steps per minute.
