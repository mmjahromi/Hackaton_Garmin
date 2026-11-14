# RaceForge final technical audit

Audit date: November 14, 2026. Inspected baseline `648996f3772575bd53cc79093becdda07d40e7aa`; tested crash fix `7281a7f5a403542df101e492bd16a2a8410a365d`. This report supersedes older milestone test totals. Source review covered all prototype Monkey C files, the eight imported modules, manifests/jungles, scripts, milestone reports, README, instructions, Git history and the fetched default's avatar/dashboard integration. `PacePilot_Architecture_Plan.pdf` was not available; current shared source/contracts were used. The supplied audit brief ends mid-sentence; no missing requirements were invented.

## Release decision

**Ready for the standalone simulator demonstration after the included P0 fix.** Normal and test builds pass on SDK 9.1.0, `fenix7pro_sim`; all original 21 tests and the new regression pass (22/22). The default-branch primary app also compiles in an isolated temporary checkout. No physical-watch verification or RaceForge dashboard synchronization is established.

One reachable crash was reproduced and fixed: regenerating a four-checkpoint plan after browsing checkpoint five left an invalid selection. The fix resets selection after replacing the plan; no coaching, sensor or teammate source changed. Remaining integration concerns are documented below. Weekly adventure integration into the primary app needs coordination; the primary app **already contains the original five avatar components and its own bridge**.

## Feature inventory

Status meanings: **Verified** = focused pure-logic behavior executed in the simulator; **Simulator only** = native/rendering/API path executed there; **Partial** = an implemented subset; **Mock/demo** = explicitly synthetic; **Unverified** = source exists without relevant physical/end-to-end evidence; **Not implemented** and **Future** are literal. None means physical-device verified. Test names below are actual test functions; source names are relative to `source/` unless prefixed `PacePilot:`.

| Feature | Source file(s) | Status | How it works | Data dependencies | Testing evidence | Known limitations | Integration requirements |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Idle and starting crouch | AvatarModel, AvatarRenderer, AvatarAnimator | Simulator only | Distinct upright/crouched joints, leaning start | Model motion/lifecycle/time | avatarAnimationFrames; avatarAllScenesAndCircularUi | Fixed procedural character | Reuse existing host classes |
| Happy/focused/winded/exhausted poses | AvatarRenderer, AvatarAdapter | Simulator only | Face, posture, flush and puff differences | Decision and optional interpreted context | avatarWorkoutAndCoachAuthority; avatarAnimationFrames | Red exhaustion demonstrated in lab; not inferred by weekly raw HR | Preserve advice authority |
| Running/walking frames | AvatarAnimator, AvatarRenderer | Simulator only | Four alternating poses, bob and breathing | Active presentation time/motion | avatarAnimationFrames; avatarSpeedAndPlayback | No motion capture or measured step matching | Parent owns redraw |
| Sweat and puff effects | AvatarAnimator, AvatarRenderer | Partial | Cyclic effects on winded/exhausted running | Visual state/breath phase | avatarAnimationFrames | Walking has distinct posture but no sweat/puffs | No added assets |
| Pace-responsive cadence | AvatarAnimator | Simulator only | Bounded nonlinear speed-to-cycle period | Valid speedMps; STILL stops movement | avatarSpeedAndPlayback | Illustrative animation, not athlete cadence | Feed existing valid speed/status |
| Pace label | AvatarAdapter | Simulator only | m/s converted to min/km; unavailable stays -- | Speed validity, movement | weeklyPaceAndLiveLifecycle | No physical GPS accuracy evidence | Existing pipeline only |
| Workout-aware expression | AvatarWorkoutContext, AvatarAdapter | Partial | Easy/tempo/walk/rest presentation context | Canonical advice plus supplied context | avatarWorkoutAndCoachAuthority | Weekly uses easy/walk/rest; tempo encouragement/red exhaustion are lab examples | Host supplies interpreted context; no new zone engine |
| Synthetic HR bands and tempo scenes | AvatarDemoController, AvatarWorkoutContext | Mock/demo | Explicit scripts classify illustrative effort separately from advice | Synthetic HR and scripted decisions | avatarAllScenesAndCircularUi; avatarWorkoutAndCoachAuthority | Not personalized zones; not live coaching | Keep lab separate and labeled |
| Missing HR neutrality | AvatarAdapter; PacePilot: Features | Simulator only | Null/not-ready/stale/missing/unsupported/error gives neutral HR UNAVAILABLE | hrReady/status/hrBpm | avatarUnavailableAndLifecycle; weeklySharedCoachingAndMissingData | No physical sensor-loss trial | Never replace null with zero |
| Paused avatar | AvatarAdapter, AdventureSession | Simulator only | Static resting pose; no stale HR/pace displayed | Shared lifecycle | avatarUnavailableAndLifecycle; weeklyPaceAndLiveLifecycle | Physical suspend behavior untested | Existing lifecycle owns pause |
| Completion celebration | AvatarAnimator, AdventureSession, AdventureView | Partial | Lab has short loop/final hold; weekly summary arms-up pose | Shared COMPLETE | avatarAnimationFrames; weeklyVerticalSlice | Weekly summary freezes at frame 0 (P2) | Any completion loop must be presentation-only |
| Lab navigation/replay/freeze | RaceForgeView, RaceForgeDelegate, RaceForgeMenuDelegate, AvatarDemoController | Simulator only / mock | START advances; easy/tempo/static modes and freeze | Scripted scenes | avatarDemoCycle; avatarStartDelegate; avatarTimerLifecycle | Historical recording is lab only | Do not import lab App/UI into host |
| Native primitive artwork | AvatarRenderer | Simulator only | Graphics.Dc lines/polygons/circles; bounded widget drawing | Caller Dc and rectangle | avatarAllScenesAndCircularUi; avatarRenderingBudget | Restores full clip/pen1, not prior caller state | Parent reapplies drawing state |
| Summit mountain | SummitRenderer, AdventureView | Simulator only | Static mountain/path; marker follows confirmed checkpoints | Journey mission count/position | weeklyEndAndRendering; weeklySetupCheckinsAndScreens | Fixed 260x260 composition, four/five points | Adapt explicit bounds if embedded |
| Manual personalization | WeeklyJourney, AdventureController/View | Partial | Baseline, 3–5 days, activity and short/medium/long time | User choices | weeklyPlanTemplates; weeklySetupCheckinsAndScreens | Experienced/intermediate share durations; mixed/running share first activity | Keep separate from coaching rules |
| Weekly mission generation | WeeklyJourney | Verified | Three/four activities plus final summit check-in | Manual profile; fixed relative available days | weeklyPlanTemplates | Illustrative week, not calendar/race planning | Agree plan identity with dashboard owner |
| Mission browsing/preview | AdventureController/View/Delegate | Simulator only | List, preview and next-unresolved start guard | Journey and selected index | weeklyPhysicalButtonDelegate; new weeklyPersonalizationShrinksPlanSafely | P0 stale selection fixed | Preserve navigation boundary |
| Goal completion/checkpoints | WeeklyJourney, AdventureController | Verified | Explicit confirmation; duplicate/old events rejected | Shared result/sessionId/goalMet | weeklyCompletionAndAdjustments; weeklyVerticalSlice | Time goal is not proof of measured active minutes | One canonical completion event |
| Summit final check-in | AdventureController, WeeklyJourney | Verified | Zero-duration administrative marker after activities | Next unresolved checkpoint | weeklyAdventureLifecycleAndWeekFinish | Not exercise; skipped week says Week reviewed | Never upload as workout |
| LIVE progress restart | JourneyStorage, WeeklyJourney | Simulator only | Versioned native Storage; completed results remain in missions | Confirmed LIVE results | weeklyNativeStorageRestart; weeklyPersistenceAndSafeDefaults | No physical restart test; app-ID scoped | Agree migration if moving to host |
| DEMO progress isolation | AdventureController, JourneyStorage | Verified / mock | Separate live/demo objects; demo exercise never persists real progress | Explicit selected source | weeklyDemoSeparationAndSaveFailure | Setup/source preference can persist configuration | Keep source explicit end-to-end |
| Start/pause/resume/end | AdventureController, AdventureSession; PacePilot: SessionController | Simulator only | Shared event dispatch and end confirmation | Existing controller/provider | weeklyVerticalSlice; weeklyPhysicalButtonDelegate; weeklyPaceAndLiveLifecycle | No physical buttons tested | Reuse existing host controller |
| Session clock | AdventureSession; PacePilot: SessionController | Simulator only | Shared controller credits time; replay input scales 4x | Provider clock; lifecycle | weeklySharedCoachingAndMissingData | Animation uses active time; long invalid deltas discarded | Do not add second elapsed clock |
| LIVE HR acquisition | AdventureSession; PacePilot: LiveProvider, Features | Unverified physically; simulator API path exercised | Imported HR listener/readiness/staleness | Sensor permission; SDK sensor inputs | weeklyPaceAndLiveLifecycle | Actual HR availability/accuracy unknown | Sensor owner retains acquisition |
| Accelerometer/movement/terrain | PacePilot: LiveProvider, Features | Simulator only / hardware unverified | Existing sample window/vote/feature pipeline | Native sensor/GPS samples | weeklySharedCoachingAndMissingData | Unknown motion stays unknown; no physical validation | Do not duplicate FeaturePipeline |
| GPS/speed acquisition | PacePilot: LiveProvider, Features | Unverified physically; simulator API path exercised | Imported positioning events and freshness | Positioning permission | weeklyPaceAndLiveLifecycle | Missing/stale gives unavailable pace | Existing provider only |
| Coaching decisions | PacePilot: CoachEngine, SessionController, Config | Simulator only | Existing HR readiness, thresholds, holds and manual events | Valid Features/config | weeklySharedCoachingAndMissingData | Manual band is illustrative, not automatically personalized | Never compute new avatar advice |
| LIVE haptic routing | AdventureSession; PacePilot: AlertService | Simulator only; physical feel unverified | LIVE/ACTIVE/ready gate; shared dedup/cooldown | decisionId/advice/current clock | weeklyPaceAndLiveLifecycle | No actual watch vibration trial | One existing host alert owner |
| Session summaries | AdventureSession, AdventureController | Verified | Pending canonical summary mapped to local result; confirm to save | Shared goal/time/motion metrics | weeklyVerticalSlice; weeklyDemoSeparationAndSaveFailure | PendingSummary.save deliberately has no durable write | Keep host SummaryStore authoritative |
| Weekly DEMO workout | AdventureSession; PacePilot: ReplayProvider | Mock/demo | Actual shared state machine on STANDARD 180s replay at 4x | Synthetic provider | weeklySharedCoachingAndMissingData | Not real exercise or full live session proof | Subscribe to existing replay in host |
| LIVE source selection | AdventureController/View, AdventureSession | Simulator only | Explicit LIVE choice; source preference restored; no synthetic fallback | Persisted sourceChoice | weeklySetupCheckinsAndScreens; weeklyPersistenceAndSafeDefaults | Physical sensor usability unverified | Visible mode badge always |
| Effort check-in | AdventureController/View, AdventureSession | Simulator only | Easy/moderate/hard => 0/1/2; nullable if skipped | User report | weeklySetupCheckinsAndScreens | Not measured exertion | Agree dashboard scale |
| Fatigue check-in | Same | Simulator only | Fresh/moderate/very fatigued => 0/1/2 | User report | weeklySetupCheckinsAndScreens | No diagnosis; not dashboard soreness | Explicit schema field needed |
| Fueling check-in | Same | Simulator only | Completed/not completed/not applicable => 0/1/2 | User report | weeklySetupCheckinsAndScreens | No carbs/fluid quantity or nutrition engine | Do not convert enum to grams |
| Fatigue adjustment proposal | AdventureController, WeeklyJourney | Verified | Very fatigued may offer shortening optional next activity | Confirmed report and mission | weeklySetupCheckinsAndScreens | No automatic physiological adaptation | Retain explicit confirmation |
| Missed/shorten/move/skip | WeeklyJourney, AdventureController/View | Verified + simulator UI | Revision-checked inert proposals; free-day move; achievements retained | Current revision/missions/days | weeklyCompletionAndAdjustments | Basic relative schedule; feedback gap on failed save | Coordinate future calendar mapping |
| Local save rollback | JourneyStorage, AdventureController | Verified | Copy before mutation; failed save restores data/retry | Storage port | weeklyDemoSeparationAndSaveFailure | CHECKIN/ADJUST_CONFIRM hide error status (P1) | Show status without changing data contract |
| Schema/history safety | JourneyStorage | Partial | Primitive string-key schema1; 8 history/12 adjustments; unknown schema preserved | Native Storage | weeklyPersistenceAndSafeDefaults; weeklyNativeStorageRestart | Some fields/ranges unvalidated; no recovery UI | Harden before importing external state |
| Pending-session restart | AdventureSession | Not implemented | Active/pending session remains memory-only | None durable until confirmation | Source review | App termination loses unsaved session/check-ins | Agree host recovery policy |
| Permissions/build isolation | manifest.xml, monkey.jungle | Verified compiler | One entrypoint; eight explicit shared imports; Sensor/Positioning | SDK9.1.0/API5.2 target | Normal/test compile | -l0, not strict typecheck certification | Keep repository relative layout |
| Physical controls/navigation | AdventureView/Delegate, legacy delegates | Simulator only | Actual BehaviorDelegate callbacks exercised | Garmin navigation | weeklyPhysicalButtonDelegate; avatarStartDelegate | Callback tests are not watch button presses | Host keeps its own delegate |
| Timer and resource cleanup | AdventureView, RaceForgeView, AdventureSession | Simulator only | Visible workout timer; hidden views stop timer/provider and release bitmap | View/lifecycle hooks | avatarTimerLifecycle; weeklyAdventureLifecycleAndWeekFinish; weeklyPaceAndLiveLifecycle | Shared sensor exception-path risk remains | Keep one tick owner and one alert owner |
| Primary PacePilot avatar embedding | Fetched default: AvatarBridge, PacePilotView, Presenter, five avatar files | Compiler verified; runtime not rerun | Existing bridge/widget integration already upstream | Existing controller snapshots | Isolated default normal build PASS | Weekly adventure not embedded; no host runtime smoke | Reuse upstream copies; never duplicate classes |
| RaceForge web synchronization | manifest/jungle/JourneyStorage | Not implemented | No Communications/uploader/callback compiled | No transport | Static review; local normalizer probe only | Dashboard cannot receive local Storage automatically | Agree mapping/identity/consent; use host uploader |
| Calendar rollover/race plans/extra mountains | WeeklyJourney, project roadmap | Future | No current implementation | Future calendar/plan contracts | Not run | Weekly template only | Separate coordinated change |
| Physical deployment/battery/HR accuracy | Device validation | Unverified | No physical evidence supplied or created | Real Fēnix 7 Pro | NOT RUN | Simulator cannot establish these claims | Hardware validation before production claims |

## Architecture and ownership

```text
RaceForgeApp (standalone entry)
  -> RaceForgeAdventureView + RaceForgeAdventureDelegate
       | one 250ms visible-workout timer / buffered screen / navigation
       v
     AdventureController -------------------> WeeklyJourney / PlanChanges
       | setup, source, selection, check-ins          | confirmed LIVE state
       v                                              v
     RaceForgeSessionBridge                      JourneyRepository
       | one imported SessionController           -> Application.Storage
       |       |                |                   raceforge.weekly.v1
       |  LiveProvider*     ReplayProvider
       |       +--> FeaturePipeline --> CoachEngine --> Decision
       |                  SessionController lifecycle/time/summary
       +--> AvatarAdapter -> AvatarModel -> AvatarAnimator -> AvatarRenderer
       +--> shared AlertService (LIVE only)

Options -> original DEMO avatar lab (its timer stops when hidden)
* thin RaceForgeLiveProvider preserves timestamp origin on shared restart
```

1. **RaceForge-owned files:** all prototype `source/*.mc`, docs, scripts and resources. Production modules are App, AdventureController/View/Session, WeeklyJourney, JourneyStorage, SummitRenderer, five avatar components and the preserved lab UI/demo controller. Tests are AvatarSmokeTests, AvatarAnimationTests, AvatarIntegrationTests, AdventureTests, WeeklyTests and AuditRegressionTests.
2. **PacePilot-owned files:** imported Contracts, Config, Features, CoachEngine, SessionController, ReplayProvider, LiveProvider and AlertService; primary App/View/Delegate/Presenter/AvatarBridge/SummaryStore and dashboard services remain teammate-owned.
3. **Actual imports:** the eight filenames above, each through `../../pacepilot-app/source/…` in `monkey.jungle`; no primary App/View, SummaryStore, DashboardSync, LiveFeed or PlanSync is imported.
4. **Reuse:** five `RaceForgeAvatar*` presentation classes unchanged from the original import. Current default already has copies with provenance comments plus AvatarBridge. Pure weekly planning/repository can be reused behind an agreed UI/result boundary.
5. **Never duplicate:** those five existing classes, any of the eight shared modules, or the global `getApp()` helper. Do not combine complete App/View/Delegate/resource trees; AppName/LauncherIcon would collide.
6. **Session controllers:** one active shared SessionController in the standalone workout; the lab has none. Current host has its own controller. Instantiating the adventure bridge alongside it would create a second instance and must be avoided.
7. **Animation:** AdventureView owns the standalone 250ms timer; hidden/static screens do not tick. The lab has a separate timer only while visible. Current default owns a 1s session timer and a 250ms redraw-only timer; the latter never ticks the controller or sensors.
8. **Vibration:** shared AlertService implements vibration/dedup/cooldown; standalone bridge gates LIVE events. Host integration must keep the existing host signal/alert owner.
9. **Completion/persistence:** shared controller creates completion/summary. RaceForgePendingSummary.save returns true without writing; explicit adventure confirmation commits a result/checkpoint through JourneyRepository. In the host keep SummaryStore ownership and associate one completion idempotently.
10. **LIVE/DEMO:** no silent measurement fallback found. Separate journeys and providers, visible badge, temporary DEMO exercise. Configuration/source choice may persist; synthetic exercise does not advance saved LIVE progress. Tests relabel a replay-backed fixture LIVE to inject storage failures: that is test data, not live sensor evidence.

Full initialization, public signatures, resources, cleanup and merge strategy: [TEAM_INTEGRATION_HANDOFF.md](TEAM_INTEGRATION_HANDOFF.md).

## Verification evidence and exact commands

SDK path read from `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`: `connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b`. Compiler reports `Connect IQ Compiler version: 9.1.0`. Prototype manifest min API5.2.0; installed Fēnix7Pro profile is API5.2, 260x260 MIP, watch-app budget786432 bytes. Compilation uses `fenix7pro_sim`; monkeydo runner uses `fenix7pro`.

Actual build/test commands, run from `prototypes/raceforge-avatar` with the existing external key (key contents were never read or copied):

```bash
bash scripts/build.sh /Users/leomajesty/Desktop/garminhackathonfolder/developer_key > bin/audit-normal.log 2>&1
bash scripts/test.sh /Users/leomajesty/Desktop/garminhackathonfolder/developer_key > bin/audit-suite.log 2>&1
# Before the production fix, compile added regression, then reproduce:
bash scripts/build.sh /Users/leomajesty/Desktop/garminhackathonfolder/developer_key --test > bin/audit-regression-build.log 2>&1
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/monkeydo" bin/RaceForge-tests.prg fenix7pro -t weeklyPersonalizationShrinksPlanSafely > bin/audit-regression-before.log 2>&1
# After resetting selected:
bash scripts/build.sh /Users/leomajesty/Desktop/garminhackathonfolder/developer_key > bin/audit-normal-after.log 2>&1
bash scripts/test.sh /Users/leomajesty/Desktop/garminhackathonfolder/developer_key > bin/audit-suite-after.log 2>&1
```

The first regression build exposed a missing `Toybox.Lang` import in the newly written test; that was corrected before reproduction. Running the stale binary after that failed compilation reported test-not-found, which is not crash evidence. The successful regression build then produced the actual `Array Out Of Bounds Error` at AdventureView.mc:74, onUpdate:69, AuditRegressionTests.mc:22. After the one-line production fix that same regression passes.

| Check | Actual outcome |
| --- | --- |
| Baseline normal/test compilation | BUILD SUCCESSFUL for both |
| Original suite | PASSED (passed=21, failed=0, errors=0) |
| Focused regression before fix | FAILED (passed=0, failed=0, errors=1); native array bounds stack above |
| Final normal/test compilation | BUILD SUCCESSFUL for both |
| Final combined suite | PASSED (passed=22, failed=0, errors=0); wrapper exit0 |
| SDK runner behavior | Exit1 even on PASS; existing wrapper requires a positive PASSED count with failed=0/errors=0 |
| Final performance observation | 600 worst-expression renders in9392ms, about15.7ms/render; retained VM before=93048, after=93048 bytes, buffer included |
| Baseline performance observation | 9434ms/600; retained92368 before/after |
| Limits of memory evidence | Simulator retained heap, not peak/native bitmap allocation, hardware FPS, battery or leak certification |
| Prototype warnings | Empty supported languages; launcher24x24 scaled to40x40 |
| Type-checking | Team -l0 setting; no claim of -l2 compliance (unchanged shared untyped modules have inference errors) |
| Duplicate declarations | Scan of final30 Monkey C source/import files found36 class/module names and no duplicates; both builds succeed |
| Prototype Git safety | No tracked key/credential/generated-binary/log filenames; ignore checks and staged review; shared files unchanged |
| Default host integration smoke | Normal compile of fetched c5fa03b isolated in /private/tmp succeeds; app not launched and no web endpoint contacted |
| Physical watch | NOT RUN: deployment, actual HR/GPS, button presses, haptic feel, MIP smoothness, battery |

Existing tests retained and executed: weeklyVerticalSlice, weeklyEndAndRendering, avatarAnimationFrames, avatarTimerLifecycle, avatarWorkoutAndCoachAuthority, avatarUnavailableAndLifecycle, avatarSpeedAndPlayback, avatarAllScenesAndCircularUi, avatarRenderingBudget, avatarDemoCycle, avatarStartDelegate, weeklyPlanTemplates, weeklyCompletionAndAdjustments, weeklyPersistenceAndSafeDefaults, weeklyNativeStorageRestart, weeklyDemoSeparationAndSaveFailure, weeklySharedCoachingAndMissingData, weeklyPaceAndLiveLifecycle, weeklySetupCheckinsAndScreens, weeklyAdventureLifecycleAndWeekFinish and weeklyPhysicalButtonDelegate. Added: weeklyPersonalizationShrinksPlanSafely.

The native Storage test uses/restores `raceforge.test.weekly.v1`, not production progress. Callback tests invoke real BehaviorDelegate methods but are not manual hardware presses. Normal LIVE API tests run against simulator inputs and do not save physical exercise. Missing HR/speed/status and paused/complete priorities were exercised. Existing screenshots `m3-setup.png` and older `m3-gate-a-summit.png` plus M2 recording are historical visual evidence; no new full-adventure recording or subjective hardware inspection occurred in this audit.

Short default-host compile commands (from repository root):

```bash
smoke_dir="$(mktemp -d /private/tmp/raceforge-host-audit.XXXXXX)"
git archive origin/dashboard-and-recovery pacepilot-app | tar -x -C "$smoke_dir"
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
cd "$smoke_dir/pacepilot-app"
"$sdk_dir/bin/monkeyc" -f monkey.jungle -d fenix7pro_sim -o "$smoke_dir/PacePilot-host-smoke.prg" -y /Users/leomajesty/Desktop/garminhackathonfolder/developer_key -w -l 0
```

Only compilation was performed for the default app; its network-enabled runtime was not launched. The audit left the original standalone backup project unchanged. Existing teammate release/*.prg files and a default-branch activity FIT file predate this contribution; no such artifact is in the avatar changes. Do not remove teammate release files during this audit; owner should confirm the FIT record's provenance before public redistribution.

## Confirmed issues and risks

Locations below refer to inspected baseline648996f; controller lines after the fix shift by one. **No unresolved P0 was found in the tested standalone paths.** This is not exhaustive failure certification.

| Priority / confidence | Description and impact | Location | Reproduction or evidence | Smallest fix | Complexity / disposition |
| --- | --- | --- | --- | --- | --- |
| P0 confirmed, FIXED | Regenerating shorter plan retains selected4; redraw crashes | AdventureController finishSetup:49–57; AdventureView:74 | Configure5days, browse fifth checkpoint, BACK HOME, MENU personalize, change to3days and finish. Focused simulator regression produced Array Out Of Bounds | Reset selected=journey.nextIndex() after replacing journey | Low; fixed7281a7f, regression passes |
| P1 confirmed integration hazard | Primary already declares same five avatar classes; importing again prevents compilation | Fetched default pacepilot-app/source/Avatar*.mc; prototype jungle | Compare default classes/provenance; adding both source directories duplicates names | Reuse existing primary copies/AvatarBridge; keep standalone isolated | Low; do not duplicate |
| P1 confirmed integration mismatch | Primary epoch sessionId exceeds repository's1e9 cap | PacePilotApp:78; JourneyStorage:19,29 | Directly pass current primary Time.now().value ID (~1.79b) to validator; it is outside accepted range | Agree ID mapping or version/widen validation before weekly embedding | Low–medium; standalone counters unaffected |
| P1 confirmed dashboard gap | Direct RaceForge result rejected; unsupported fields lost | AdventureSession:103–109; web lib/pace.js, store.js | Local normalizer: Invalid goalSec, then Invalid sessionSec; mapped baseline accepted but mission/fatigue/fueling dropped | Preserve canonical summary and agree versioned mission/check-in schema/identity | Medium; no current uploader |
| P1 confirmed activity wording/control gap | Walking/recovery/mobility can offer READY TO RUN / UP run, despite planned activity | AdventureSession:48–65; AvatarAdapter:83–87; AdventureView:151; AdventureController:153–154 | STANDARD replay reaches shared READY_TO_RUN during these mission types; source retains headline/control | Coordinate activity-specific wording/acceptance with session owner while preserving canonical advice | Low–medium; nonblocking for easy-run demo |
| P1 confirmed UI feedback gap | Save rollback is correct, but final check-in/change screen hides failure reason | AdventureController:72,132; AdventureView:101–117 | Inject failing storage write, confirm final check-in or adjustment; stays on screen without status message | Render existing flow.status on both screens, keep retry | Low; not data loss or false-success |
| P1 source-confirmed exception risk, hardware unexercised | HR may remain enabled if event registration throws after enabling; stop checks ownership flag set later | Shared LiveProvider:24–30,80–85 | Inspect setEnabledSensors -> enableSensorEvents -> sensorOwned ordering; no fault-injected hardware trigger | Sensor owner tracks enabling earlier or unwinds in catch | Low; do not edit team sensor module here |
| P2 confirmed | Weekly summary celebration remains static frame0 | AdventureSession:56,68; AdventureController:45–46; AdventureView:24 | Complete any replay; session time freezes and summary timer stops | Accept static pose or bounded presentation-only completion clock | Low; lab loop already works |
| P2 hardening risk | Validator permits some unchecked check-in/adjustment/source/mission fields | JourneyStorage:24–59 | Read validation; normal flows generate valid state; no external corrupt-state exploit claimed | Validate optional fields/ranges, mission types and final summit before future import | Medium; no external input currently |
| P2 confirmed scope limits | Relative illustrative week; basic preference distinctions; no rollover/reset/corrupt recovery UI | WeeklyJourney:14–30; JourneyStorage:74–80 | Source/template tests; compare intermediate/experienced and running/mixed | Document for submission; separate future calendar/recovery work | Medium; future scope |
| P2 source-observed embedding constraint | Renderer restores full clip rather than caller clip; summit assumes260x260 | AvatarRenderer:34–41,121–122; SummitRenderer | Parent with custom clip must reapply after drawing | Restore caller graphics state in host, agree widget bounds | Low; current isolated layout unaffected |

Checked without observed normal-path failure: App entry isolation, one controller per standalone session, normal listener cleanup, stopped hidden timers, pause/restart clock continuity, missing measurements, explicit badges, no DEMO progress contamination, distinct Storage keys, idempotent checkpoint saves and shared alert gating. Risks from duplicating controllers/timers/haptics/resources arise when combining apps wholesale; they are not existing standalone double-acquisition bugs.

## Dashboard and stored data

`Application.Storage` is local app storage; it does not synchronize with the dashboard. RaceForge's manifest has Sensor and Positioning only; its build excludes network uploaders. No RaceForge end-to-end upload exists or was tested.

| Stored object | Actual fields / meaning |
| --- | --- |
| Root schema1 | schemaVersion, challenge=WEEKLY, configured, sourceChoice, profile, availableDays, missions, position, revision, sequence, history(max8), adjustments(max12) |
| Profile | level, days, activity, time: manually selected integer choices |
| Mission | missionId, title, activityType, durationTargetSec, effortTarget, hrLow/hrHigh, plannedDay, status, optional, result |
| Session result | schemaVersion, sessionId(local counter), mode, goalMet, elapsedSec, movingSec, unknownMotionSec, hrValidSec, endedAt, nullable effort/fatigue/fueling; finish adds missionId |
| Reports | effort easy/moderate/hard=0/1/2; fatigue fresh/moderate/very fatigued=0/1/2; fueling completed/not completed/not applicable=0/1/2; unanswered=null |
| Administrative summit | ID/mode/goalMet and zero elapsed/moving/unknown values; no workout implied |
| Adjustment | revision, index, kind, allowed, missionId, proposed duration/day and explanation; confirmed only |

The fetched default web dashboard has `/api/pace-sessions`, `/api/live` and newer profile/plan/decision/watch-config APIs. Pace sessions require goalSec/sessionSec/walkPromptCount and consistent totals. RaceForge omits goalSec/walkPromptCount and calls session time elapsedSec, although the underlying shared canonical summary has the necessary workout fields. Current normalizer does not retain fatigue/fueling/missionId. Newer optional planId/carbsG/fluidMl are not equivalent to those fields. The live endpoint accepts app pacepilot/guttrain, not raceforge. The local no-network normalizer probe is evidence of schema incompatibility, not a server integration test.

Server upsert identity is mode+sessionId; standalone counters starting at1 can collide between installs. Mission week-1… IDs/relative days have no calendar week anchor or dashboard planId. Summit check-ins must not be sent as successful zero-duration exercise. Future exchange needs agreed global identity, week/date/plan link, nullable check-in semantics, idempotency/retry and explicit sharing consent. Reuse the existing host summary/uploader and supported asynchronous Communications.makeWebRequest after agreement; no second uploader/coaching engine is needed. Distinct standalone/host application UUIDs also mean no automatic migration of local records.

See the companion handoff for exact paths/interfaces and the remote relationship. No branch merge, force push, teammate source overwrite, production API call or deployment occurred during the audit.
