# Milestone 3 — implementation and verification

## Implemented

The production entrypoint now opens the weekly adventure. The generated App class
and original avatar lab remain; all five reusable avatar files are unchanged.

Flow: setup → summit → missions → preview → animated workout → pause/resume/end
confirmation → summary/check-ins → explicitly saved checkpoint → updated summit.
The weekly check-in is a final milestone, not another prescribed workout.

The app generates four or five checkpoints from manual baseline/day/activity/time
choices. Mobility and recovery are deliberately shorter, optional sessions. A
manual HR band is confirmed before a session. Walking, missing-HR neutrality,
easing, permitted return-to-run and completion use the existing adapter/artwork.
The summit is static: it never changes position just because time passes.

DEMO runs the real shared coaching state machine and replay at 4×, freezes on
pause, and keeps progress in memory. LIVE uses the shared native HR, accelerometer
and GPS provider; missing, stale or invalid data never falls back to demo data.
The last confirmed source is restored after restart, so saved LIVE checkpoints
appear on the returning summit without switching away from an empty demo. The
active view shows mode, HR/pace availability, configured range, instruction,
controller elapsed time and a goal-time bar. Unknown motion is not active minutes.

Confirmed LIVE results persist using Application.Storage under
`raceforge.weekly.v1`. Schema 1 has string keys, primitive values, arrays and
dictionaries only. Real and demo journeys are separate objects. Session IDs are
monotonic, older/duplicate result events are rejected, and completed missions keep
their results even when the rolling summary list is trimmed. At most 8 summaries
and 12 confirmed changes are retained. Save failures restore pre-save progress;
unknown/corrupt versions are preserved rather than replaced with empty progress.

Effort, fatigue and fueling check-ins are explicitly user-reported and stored
locally. Missed, shorten-optional, move-to-free-day and skip actions require review
and confirmation. No previous achievement is removed. Moves sort only remaining
missions and never place two sessions on the same available day. The final title
is “Week reviewed” if some activities were skipped, rather than claiming all were
completed. No automatic compensatory training or physiological diagnosis exists.

## Shared-code integration and ownership

Only files beneath `prototypes/raceforge-avatar/` changed. The build explicitly
imports these teammate files, once each, with no edits:

| Module | Ownership |
| --- | --- |
| Contracts.mc | Reading and snapshot structure |
| Config.mc | Existing validated coach configuration |
| Features.mc | HR readiness/staleness, speed validity, movement and terrain |
| CoachEngine.mc | All advice transitions and resume permission |
| SessionController.mc | Lifecycle, elapsed/moving/unknown time and completion |
| ReplayProvider.mc | Deterministic synthetic input |
| LiveProvider.mc | Raw sensor/GPS acquisition and cleanup |
| AlertService.mc | Haptic deduplication/cooldown and vibration |

These files also match the fetched default branch's versions; none was modified
by this feature. The PacePilot App/View and dashboard are outside the build.
No Communications permission or web synchronization is introduced.

The narrowly scoped RaceForgeLiveProvider subclass only preserves the original
provider timestamp origin across pause/resume resource restarts. It calls the
existing start/stop implementation; it does not reimplement sensor callbacks.
Both modes use one shared SessionController. The separate DEMO replay clock is an
input-time scale, not another workout-duration accumulator. Animation time is
derived from shared active session seconds, divided by playback rate in DEMO.

The app reads the shared `:hr`/`:speed` status keys and preserves advice, reason,
decisionId and canResumeRun. The shared controller keeps its pending summary in
memory; the adventure performs its own durable write only after user confirmation.
LIVE haptics go through the shared AlertService; renderer code has no haptic calls.

## Actual verification — November 14, 2026

Environment: SDK **9.1.0**, standard Fēnix 7 Pro API **5.2**, compile target
**fenix7pro_sim**, simulator runner **fenix7pro**. Normal and test builds succeed.

The combined build uses the team's `-l 0` setting. At `-l 2`, the unchanged shared
CoachEngine/Features files produce inference errors (nullable decisionId addition
and an inferred empty-array index). This is documented rather than “fixed” by
editing team code. The SDK still compiles against the device's supported APIs;
the simulator tests exercise the integration. The only emitted build warnings at
`-l 0` are the inherited language-resource and launcher-icon scaling warnings.

| Test | Expected / observed | Result |
| --- | --- | --- |
| weeklyVerticalSlice | Select, shared replay, pause/resume, summary, explicit checkpoint | PASS |
| weeklyEndAndRendering | Render first-slice screens; early end gives no checkpoint | PASS |
| avatarAnimationFrames | Original timed poses, effects and final hold | PASS |
| avatarTimerLifecycle | Original lab show/hide/freeze cleanup | PASS |
| avatarWorkoutAndCoachAuthority | Original workout context/advice authority | PASS |
| avatarUnavailableAndLifecycle | Original sensor status/lifecycle precedence | PASS |
| avatarSpeedAndPlayback | Original speed bounds, stillness, freeze | PASS |
| avatarAllScenesAndCircularUi | Original scenes and native font clearance | PASS |
| avatarRenderingBudget | 600 renders, retained VM memory stable | PASS |
| avatarDemoCycle | Original six-state regression | PASS |
| avatarStartDelegate | Original START/navigation regression | PASS |
| weeklyPlanTemplates | 27 baseline/day/time combinations; actual checkpoint counts | PASS |
| weeklyCompletionAndAdjustments | No duplicate completion; inert/revision-checked proposals; safe move | PASS |
| weeklyPersistenceAndSafeDefaults | Restart, bounded history, old-event rejection, corrupt/new schema safety | PASS |
| weeklyNativeStorageRestart | Real Storage save/load with 8 summaries and 12 changes; isolated test key | PASS |
| weeklyDemoSeparationAndSaveFailure | DEMO cannot alter real progress; failed LIVE save rolls back and retries | PASS |
| weeklySharedCoachingAndMissingData | Shared engine ease/walk/ready; paused time; no false motion credit | PASS |
| weeklyPaceAndLiveLifecycle | Pace/invalid/stale handling; real API-path start/stop, LIVE session pause/resume/reacquisition/end; haptic gate | PASS |
| weeklySetupCheckinsAndScreens | Setup/source/band/adjustment/check-ins render within measured circle bounds | PASS |
| weeklyAdventureLifecycleAndWeekFinish | No hidden timer work; full week ends only on explicit check-in | PASS |
| weeklyPhysicalButtonDelegate | Actual START/UP/DOWN/BACK/MENU callback routing | PASS |

Final summary: **21 passed, 0 failed, 0 errors**. The SDK runner returns 1 despite
PASS; the test script verifies the actual summary and exits successfully. Raw logs
are ignored at `bin/simulator-tests.log` and `bin/build.log`.

Latest 600-render measurement: 12,287 ms (about 20 ms per character render), with
retained VM usage 93,448 bytes before and after. This is a host-simulator observation,
not physical frame timing, native graphics memory accounting or a battery claim.
The app retains one screen bitmap, releases it on hide, and animates only an active
workout at 4 updates/sec. The summit and menus do not continuously redraw.

The native Storage test uses `raceforge.test.weekly.v1` and restores that test key;
it never writes the real journey key. LIVE API tests do not save real exercise.
The screenshot at `evidence/m3-setup.png` is the final actual simulator setup screen.
`evidence/m3-gate-a-summit.png` records the first vertical-slice checkpoint
81599e2, before the later spacing/layout refinement. Final screens are additionally
exercised with native buffered contexts; there is no new full-adventure video.

| Unrun validation | Status |
| --- | --- |
| Physical-watch HR/GPS accuracy and acquisition | NOT RUN |
| Physical button presses on hardware | NOT RUN; simulator delegate callbacks pass |
| On-device MIP smoothness/battery/haptic feel | NOT RUN |
| End-to-end dashboard transport | NOT IMPLEMENTED / NOT RUN |
| Calendar rollover, race-specific plans, respiration diagnostics, extra mountain styles | FUTURE |

The original milestone-2 recording remains historical art evidence. Some captured
frames omit gray captions. Do not infer flawless physical MIP rendering or live
physiological validation from screenshots or tests.

## Build and merge handoff

Use README.md for exact build/test commands. Keep the full repository when building
this app because monkey.jungle imports the shared local files by relative path.
Garmin's installed Sensor/Position/Storage APIs and permissions were inspected
before dependent features; only Sensor and Positioning permissions were added.
The signing key stays outside git; binaries, raw logs and keys are ignored.

Checkpoint 81599e2 established the demo vertical slice before LIVE and storage.
The later checkpoint adds shared acquisition, versioned persistence, personalization
and check-ins. No branch merge or force push is needed to inspect the prototype.
The standalone backup project remains unchanged.

Before embedding into the primary PacePilot application, agree widget bounds,
parent animation ownership, lifecycle pause/resume/completion callbacks and haptic
ownership with the UI owner. Reuse its existing controller instance: do not create
a second SessionController alongside it. Existing five avatar components remain
transferable. Adventure navigation/planning/storage are independent UI concerns.

Future dashboard exchange (documentation only; no transport is wired):

```json
{
  "schemaVersion": 1,
  "app": "raceforge",
  "mode": "LIVE",
  "missionId": "week-1",
  "sessionId": 1,
  "goalMet": true,
  "elapsedSec": 300,
  "movingSec": 240,
  "unknownMotionSec": 60,
  "effort": 1,
  "fatigue": 0,
  "fueling": 2,
  "endedAt": 1794670000
}
```

Numbers here are illustrative. Check-in scales: effort easy/moderate/hard = 0/1/2,
fatigue fresh/moderate/very fatigued = 0/1/2, fueling completed/not completed/not
applicable = 0/1/2. Unanswered check-ins are null. Never export DEMO as real exercise
or treat unknown-motion seconds as verified activity. Any future sharing requires
an agreed supported transport and explicit consent; no sharing currently occurs.
