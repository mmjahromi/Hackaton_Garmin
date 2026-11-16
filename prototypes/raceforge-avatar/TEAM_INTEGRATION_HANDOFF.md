# RaceForge team integration handoff

Audit snapshot: November 14, 2026. Inspected milestone-3 baseline648996f; verified source/fix commit `7281a7f5a403542df101e492bd16a2a8410a365d`. Companion [final audit](FINAL_TECHNICAL_AUDIT.md) records the complete inventory, fresh results and findings. The documentation commit follows that source commit; `git log -1` gives its final publication hash.

## Git snapshot and scope

| Item | Verified value |
| --- | --- |
| Repository | `https://github.com/mmjahromi/Hackaton_Garmin.git` |
| Feature branch | `feature/raceforge-avatar` |
| Published baseline | `648996f3772575bd53cc79093becdda07d40e7aa` — `feat: persist weekly adventure and reuse PacePilot live sessions` |
| Remote at initial inspection | `origin/feature/raceforge-avatar` matched baseline648996f; the audit adds a crash-fix commit and this documentation |
| Default branch | `dashboard-and-recovery` |
| Fetched default | `c5fa03b59bc49d22a8e254464cdc74f2a606f65f` |
| Merge base | `e73433b3410978808685377c6f9ee54096f3d4ca` |
| Divergence at inspected baseline | Default has six unique commits; baseline feature has two unique commits. The fix and documentation add two feature commits |
| Branch URL | https://github.com/mmjahromi/Hackaton_Garmin/tree/feature/raceforge-avatar |
| Existing draft PR | https://github.com/mmjahromi/Hackaton_Garmin/pull/2 — open, targeting `dashboard-and-recovery`; no merge performed |

The baseline PR's triple-dot diff contains 19 paths, all below `prototypes/raceforge-avatar/`: AGENTS.md, PROJECT.md, README.md, MILESTONE3.md, manifest.xml, monkey.jungle, both scripts, two milestone-3 screenshots, and source/AdventureController.mc, AdventureSession.mc, AdventureTests.mc, AdventureView.mc, JourneyStorage.mc, RaceForgeApp.mc, SummitRenderer.mc, WeeklyJourney.mc and WeeklyTests.mc. Upstream-only files visible in a two-dot tree comparison are not feature-branch deletions.

The audit reproduced a selected-index crash after regenerating a shorter plan. Commit `7281a7f` resets selection after assigning the new journey and adds `source/AuditRegressionTests.mc`. Final normal/test builds pass and all22 simulator tests pass. Audit-only additions beyond the19 baseline paths are that regression file, FINAL_TECHNICAL_AUDIT.md and TEAM_INTEGRATION_HANDOFF.md (22 contribution paths total); README links the reports and updates its count. The audit changes only the isolated prototype. Verify the final feature publication hash with `git log -1` or the PR; do not merge automatically.

## Existing primary-app integration

The fetched default already contains `pacepilot-app/source/AvatarModel.mc`, `AvatarRenderer.mc`, `AvatarAdapter.mc`, `AvatarAnimator.mc` and `AvatarWorkoutContext.mc`. Their implementation matches the prototype byte-for-byte after removing the single added provenance comment. It also contains `AvatarBridge.mc`, avatar tests and actual PacePilotView/Presenter rendering calls.

**Reuse those existing primary-app classes.** Do not copy the five classes again, add the whole prototype directory to PacePilot's source path, or replace its App/View/Delegate. Primary `AvatarBridge.model(features, decision, lifecycle, config, timeMs)` already sanitizes the shared snapshot and maps presentation context without changing coach advice.

For the current milestone-3 work, keep the standalone prototype separately buildable. The weekly navigation/planning/storage changes have not been integrated into the primary app. Any later weekly integration needs a small UI-owned boundary around the existing controller, rather than a second RaceForgeSessionBridge beside it.

## Ownership and lifecycle

```text
PacePilot LiveProvider / ReplayProvider
                  |
        FeaturePipeline + CoachEngine
                  |
           SessionController
          /       |        \
 shared alerts  summaries  Features + Decision + Lifecycle
                           |
                    existing AvatarBridge
                           |
                 AvatarModel + Animator
                           |
                    AvatarRenderer
                           |
              existing PacePilotView / Presenter

Standalone RaceForge only:
AdventureView -> AdventureController -> RaceForgeSessionBridge
                          |             -> one shared SessionController
             WeeklyJourney / Repository
```

| Concern | Standalone implementation | Primary integration ownership |
| --- | --- | --- |
| Init | RaceForgeApp creates AdventureView/Delegate; AdventureView loads JourneyRepository | Keep PacePilotApp, PacePilotView, Delegate and existing AvatarBridge |
| Sensors/coaching | Eight unmodified shared modules are compiled through explicit jungle paths | Existing provider/pipeline/coach/controller; do not create another provider or engine |
| Update | AdventureView owns one 250 ms visible-workout timer | PacePilot's existing 1 s session timer remains authoritative; its separate 250 ms avatar timer only requests redraw |
| Advice | Adapter consumes Decision; HR/speed are presentation data | Existing shared Decision is authoritative; preserve decisionId/canResumeRun |
| Pause/resume | Adventure controller dispatches through bridge; LIVE provider resources stop/restart while preserving timestamp origin | Existing lifecycle dispatch; invalidate stale readings through shared pipeline; render paused model without advancing animation |
| Hidden/exit | AdventureView onHide suspends session, stops timer and releases surface; onStop calls shutdown | Keep primary onHide avatar cleanup and shutdown; no redraw work when hidden |
| Haptics | RaceForge bridge gates shared AlertService to LIVE | Existing PacePilot signal/AlertService only; never emit from renderer or a second bridge |
| Completion | Shared controller creates canonical pending summary; explicit RaceForge confirmation awards checkpoint | One completion event/session identity; UI owner decides when to commit weekly achievement, idempotently |
| Persistence | RaceForge repository owns `raceforge.weekly.v1`; DEMO journey is temporary | Keep PacePilot SummaryStore ownership; agree separate weekly storage/migration, not duplicate summary writes |

Current default has two intentionally separate timers: the 1 s controller tick and 250 ms drawing tick. `onAvatarTick()` never acquires sensors, advances replay, emits haptics or ticks the controller (`PacePilotApp.mc:402–415`). Do not add AdventureView's timer to that screen.

## Public presentation calls

```monkeyc
var adapter = new RaceForgeAvatarAdapter();
adapter.configureSourceKeys(:hr, :speed); // these are the current shared status keys
var renderer = new RaceForgeAvatarRenderer();
var animator = new RaceForgeAvatarAnimator();

var model = adapter.fromPacePilot(features, decision, lifecycle, :EASY_RUN, timeMs);
// Optional externally interpreted presentation context:
var context = new RaceForgeAvatarWorkoutContext(:EASY_RUN, low.toFloat(), high.toFloat());
model = adapter.fromContext(features, decision, lifecycle, context, timeMs);
animator.apply(model, timeMs); // mutates retained presentation fields only
renderer.draw(dc, model, left, top, width, height);
```

Actual signatures are `fromPacePilot(features, decision, lifecycle, workoutType, animationTimeMs)`, `fromContext(features, decision, lifecycle, context, animationTimeMs)`, `apply(model, animationTimeMs)`, `periodMs(model)` and `draw(dc, model, left, top, width, height)`. The renderer draws the character only; parent code clears the destination, draws labels and requests updates. It resets clip to the full Dc and pen width to 1, so the caller must restore parent clip/color/pen state. Bounds below 24 px draw nothing. The renderer needs no PNG/sprite resource.

Use the existing primary `AvatarBridge.model(...)`/`prepareAvatar(...)` calls when working on the current default. The code above documents the reusable boundary, not a second path to add alongside them. Optional LIVE context must come from existing interpreted state; `setDemoEffort()` is only for illustrative DEMO classification. Unknown/not-ready HR stays neutral. Visual speed is a bounded illustrative cadence, not measured step frequency.

SummitRenderer currently assumes the standalone 260 × 260 layout and does not accept bounds. Reusing it in another layout needs a small explicit bounds/scaling change coordinated with the UI owner. AdventureController/View are standalone navigation, not drop-in widgets.

## Source paths, manifest and resources

Prototype `monkey.jungle` compiles its own `source` plus exactly:

```text
../../pacepilot-app/source/Contracts.mc
../../pacepilot-app/source/Config.mc
../../pacepilot-app/source/Features.mc
../../pacepilot-app/source/CoachEngine.mc
../../pacepilot-app/source/SessionController.mc
../../pacepilot-app/source/ReplayProvider.mc
../../pacepilot-app/source/LiveProvider.mc
../../pacepilot-app/source/AlertService.mc
```

Keep the repository layout intact for these relative imports. Do not add the prototype jungle imports to the primary app: its existing `base.sourcePath = source;tests` already includes these classes. Do not import RaceForgeApp, AdventureView/Delegate, legacy View/Delegate/MenuDelegate, demo controller or prototype test files into primary production source.

The prototype UUID is `1c1a38a6-eada-4bb8-a828-b7ac7c44aede`, entry `RaceForgeApp`, min API `5.2.0`, product `fenix7pro`, permissions Sensor and Positioning. The primary UUID/entry remain PacePilot's; the default already declares SensorHistory, Communications, Sensor and Positioning. Avatar-only rendering requires no added permissions. Primary minApiLevel currently remains 3.2.0 in its teammate-owned manifest; its broader compatibility claim was not established by this prototype audit.

Both resource sets define AppName and LauncherIcon. Prototype MainLayout/MainMenu and menu strings belong to its standalone lab. Do not combine resource trees wholesale; no avatar artwork resource transfer is required. Retain original standalone art/docs/evidence under the prototype directory.

## Build and evidence

From `prototypes/raceforge-avatar/`:

```bash
bash scripts/build.sh /absolute/path/to/developer_key
bash scripts/test.sh /absolute/path/to/developer_key
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
"$sdk_dir/bin/monkeydo" bin/RaceForge.prg fenix7pro
```

The scripts require compiler version exactly 9.1.0, compile using `-d fenix7pro_sim -w -l 0` (test adds `-t`) and run tests using `fenix7pro`. They check the official zero-failure PASSED summary because this SDK's runner can return a nonzero exit despite that summary. Do not weaken the existing pass check or report compilation alone as simulator validation. Level 0 matches the shared sources; it does not establish stricter type-check compliance. Expected inherited warnings concern absent language-specific resources and scaled launcher icon. Fresh normal/test builds both succeeded; final summary is PASSED (passed=22, failed=0, errors=0). The original21 tests also passed before the fix. See final audit for exact commands/results.

Published milestone-3 documentation records 21 simulator tests; screenshots/video include historical milestone evidence, not physical-watch validation. The new regression reproduces a native bounds error before the one-line fix and passes afterward. An isolated fetched-default PacePilot normal compile also succeeds; its runtime was not launched. No physical Fēnix, battery, real GPS accuracy, vibration feel or end-to-end RaceForge dashboard transport claim is established here.

Prototype `.gitignore` excludes bin, PRGs/debug XML, logs, .DS_Store, developer_key*, DER/PEM/KEY/P12/PFX and env files. Keep the signing key outside Git and review staged files. No merge, force push, source overwrite or public deployment is part of this handoff.

## Dashboard contract and future sync

RaceForge currently has no web transport: no Communications permission/import, no DashboardSync/LiveFeed/PlanSync source path and no send callback. `Application.Storage` is local persistent disk storage, not dashboard synchronization. Its separate app identity also means importing a widget does not establish migration of an installed standalone app's records.

RaceForge persists a versioned weekly object: manual profile, relative available days, 4/5 missions, selected source preference, completed position, sequence/revision, latest eight result records and latest twelve adjustments. Mission records include missionId/title/activityType/durationTargetSec/effortTarget/manual HR band/plannedDay/status/optional/result. Session result has schemaVersion/sessionId/mode/goalMet/elapsedSec/movingSec/unknownMotionSec/hrValidSec/endedAt/nullable effort/fatigue/fueling; finishing attaches missionId. The administrative summit marker instead has a zero-duration result and must stay separate from exercise summaries.

| Gap | Required agreement before wiring |
| --- | --- |
| Summary shape | Existing `/api/pace-sessions` requires goalSec, sessionSec, walkPromptCount and consistent totals. RaceForge calls duration elapsedSec and omits goal/cue fields. Preserve the canonical shared summary rather than fabricate totals. |
| Identity | RaceForge sessionId is a local counter; server upserts by mode+sessionId. It needs a stable agreed identity/namespace before independent installations upload. Current primary uses epoch seconds. |
| Mission linkage | RaceForge relative IDs/week days have no week start/date or dashboard planId. Current default marks plans done by planId, not missionId. Agree calendar/week identity, revision/conflict and linkage semantics. |
| Check-ins | effort requires explicit semantic mapping; fatigue is not soreness/energy, and fueling 0/1/2 is not carbsG/fluidMl. Current pace normalizer discards missionId/fatigue/fueling. Add versioned supported fields/endpoints if needed. |
| Newer default schema | Default additionally accepts optional planId/carbsG/fluidMl. Its profile/plan/decision/watch-config APIs are a separate calendar planner, not an existing RaceForge sync protocol. |
| Live stream | `/api/live` accepts only pacepilot/guttrain plus sessionId/sequence/sample time/status. It does not accept `app: raceforge`; no live uploader is present in RaceForge. |
| Administrative markers | Do not POST summit check-ins as successful workouts: goalMet with zero duration fails exercise summary consistency rules. |

A local no-network normalizer check rejected the direct RaceForge result with `Invalid goalSec`, then `Invalid sessionSec` after adding a goal. Explicit baseline mapping accepted but dropped unsupported fields. No production endpoint was called.

Safest future route: let the existing primary summary store/uploader retain ownership, add one explicit user-consented mission association, and introduce a narrowly versioned weekly endpoint/schema only if the team needs it. Use Garmin's supported asynchronous `Communications.makeWebRequest` with the existing sharing UI, offline/retry/idempotency handling and optional ingest authentication; verify the endpoint response before claiming upload. Installed SDK 9.1.0 documents this API and Communications permission. Do not add another sensor or coaching engine. Do not silently upload DEMO, map unknown motion to measured activity, or treat storage writes as successful network exchange.

## Teammate access and final handshake

Use a clean checkout or isolated worktree; preserve any existing uncommitted work. Fetch origin, inspect `feature/raceforge-avatar`/PR 2, and build from the prototype subdirectory. For avatar-only changes on the latest default, begin from its already integrated `pacepilot-app/source/AvatarBridge.mc` and five components.

Before weekly integration, UI owner and session owner should confirm: allotted screen bounds; existing controller instance; advice/lifecycle/event ownership; one alert owner; canonical completion/session identifier; when weekly confirmation persists; nullable check-in mapping; DEMO isolation; storage namespace/migration; and whether any dashboard exchange is in scope. Keep the standalone app as a reference and integrate the smallest agreed boundary. The final audit supplies the post-fix test evidence and remaining concerns; this document does not authorize a merge.

## Weekly interfaces for a later coordinated integration

- `RaceForgeWeeklyPlan.defaults()`, `validProfile(profile)`, `generate(profile)`.
- `new RaceForgeWeeklyJourney(state)`; `.data`, `missions()`, `nextIndex()`, `isComplete()`, `completed()`, `finish(index, result)`.
- `RaceForgePlanChanges.propose(journey, index, kind)` and `confirm(journey, proposal)`; never mutate from an unconfirmed suggestion.
- `new RaceForgeJourneyRepository(storagePort)`; `load()`, `save(journey)`, `key`, `writable`, `error`. Storage port supplies `read(key)`, `write(key, value)`.
- `new RaceForgeSessionBridge(mission, mode, sessionId)`; `step(deltaMs)`, `refresh()`, `event(symbol)`, `result()`, `stop()`. This is standalone composition, not a bridge to instantiate beside the primary controller.
- Adventure controller: `restore(repo)`, `setMode(mode)`, `step(deltaMs)`, `select()`, `move(delta)`, `menu()`, `back()`, `suspend()`, `stop()`, `commitResult()`.

Initialization in the standalone app: create View/flow; load repository and selected source; configure week; user selects next mission; reserve durable LIVE sequence before session acquisition; create exactly one bridge/controller; show/tick only WORKOUT; use shared PAUSE/RESUME/END events; explicit check-in/save commits; onHide suspends and onStop shuts down. For primary weekly integration replace the bridge construction with an agreed snapshot/result/event boundary to the already existing host controller. Epoch-based host IDs exceed the current repository1e9 limit; agree mapping or a versioned validator change first.

Safe teammate access, from a clean checkout without disturbing local edits:

```bash
git fetch origin
git worktree add --detach /private/tmp/raceforge-review origin/feature/raceforge-avatar
cd /private/tmp/raceforge-review/prototypes/raceforge-avatar
bash scripts/build.sh /absolute/path/to/developer_key
bash scripts/test.sh /absolute/path/to/developer_key
```

Choose an unused worktree path. Review PR2 against dashboard-and-recovery; no checkout, cherry-pick or merge into a dirty worktree is required to inspect/build.
