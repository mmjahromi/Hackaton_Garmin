# RaceForge — weekly fitness adventure

A functional, offline Monkey C watch app for the Fēnix 7 Pro (260 × 260 round MIP,
API 5.2), extending the existing animated athlete without replacing its artwork.
Choose a baseline and a gentle weekly plan, follow its mountain checkpoints, and
confirm completed missions. Walking and recovery are planned activities.

Merged into `dashboard-and-recovery` on 14 November 2026. See [current project status](../../STATUS.md). The original avatar presentation components are already embedded in PacePilot; this standalone adventure remains independently runnable. Its weekly journey is now also integrated into PacePilot through `source/Weekly.mc`, using PacePilot's existing workout/feedback and sharing. The trail itself is local in each app.

The prototype lives separately from PacePilot. It imports the team's actual
controller, providers, pipeline and coaching engine by source-file path; it does
not implement another coaching engine, session clock, web app or upload service.

## Build from this repository

Open **prototypes/raceforge-avatar** in VS Code with Garmin's Monkey C extension.
Keep the full team checkout: `../../pacepilot-app/source/` supplies the shared
modules. Select SDK **9.1.0 exactly** and keep the signing key outside git.

```sh
cd prototypes/raceforge-avatar
bash scripts/build.sh /absolute/path/to/developer_key
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
"$sdk_dir/bin/monkeydo" bin/RaceForge.prg fenix7pro

# Native simulator tests, including the original nine avatar regressions:
bash scripts/test.sh /absolute/path/to/developer_key
```

Compiler target: `fenix7pro_sim`. Runner: `fenix7pro`. The combined build uses
PacePilot's existing `-l 0` setting because its untyped modules produce inference
errors at `-l 2`. No teammate source was edited. The renderer, model, animator,
adapter and workout context remain unchanged from milestone 2.

## Play the first mission

1. On first launch use UP/DOWN to choose baseline, available days, preferred
   activity and daily time; START accepts each of the four choices.
2. The summit opens in clearly labeled **DEMO**. START opens missions, START
   previews the highlighted mission, then START begins it.
3. The shared PacePilot 180-second replay runs at 4× (about 45 wall seconds).
   Running animation stays at a normal visual rate while coaching time advances.
4. At the summary, START opens the optional local check-ins; confirm all three to
   record the result. Hold MENU on the summary saves without check-ins.
5. The checkpoint moves only after this explicit confirmation. DEMO progress is
   temporary and does not change the saved LIVE journey.

For LIVE: hold MENU on the summit → Workout source → choose LIVE → START.
The next mission uses its actual configured duration and the shared HR/GPS provider.
Missing measurements remain unavailable. The app starts in DEMO on first launch, then restores the last confirmed source
and its real progress after restart. No sensors start merely by browsing.

## Buttons

| Screen | START | UP / DOWN | BACK / hold MENU |
| --- | --- | --- | --- |
| Setup | Accept choice / create week | Change selection | BACK uses defaults for temporary demo |
| Summit | Mission list | — | BACK exits; MENU opens source/setup/avatar lab |
| Missions | Preview | Select mission | BACK summit |
| Preview | Start current mission | Review manual HR band | BACK list; MENU missed/change options |
| Workout | Pause | DOWN manual walk; UP accepts run only when allowed | BACK pauses and asks to end |
| Paused | Resume | — | BACK end confirmation |
| End confirmation | Confirm highlighted choice | Keep paused / end | BACK keeps paused |
| Summary | Check-in | — | MENU saves without check-in |
| Check-in | Accept answer / save | Select answer | BACK summary |
| Change proposal | Confirm highlighted choice | Keep original / confirm | BACK keeps original |

The old animated easy/tempo/static avatar lab is under summit MENU → Avatar pose
lab. Its existing controls and all nine tests are preserved.

## Progress, storage and adjustment semantics

- Three available activity days produce three sessions plus the summit check-in
  (four checkpoints). Four/five available days produce four sessions plus the
  summit (five checkpoints); the fifth available day can remain a flexible day.
- Beginner templates are short and include optional mobility and recovery. HR
  bands are manual illustrative settings, not inferred from fitness level.
- Days are relative plan days 1–7, not a detailed calendar or automatic rollover.
- The shared controller owns elapsed, moving and unknown-motion seconds. A timed
  mission is not proof of verified active minutes: unknown motion is reported.
- A result below its time goal is saved as partial and awards no checkpoint.
- Missed/skipped missions never erase earned checkpoints. Shorten/move/skip are
  inert proposals until explicitly confirmed. Moving reorders only the remaining
  itinerary, preserves achievements and uses an unoccupied available day.
- Skips remain visibly skipped, not fabricated completions. The final explicit
  weekly check-in closes the week; with skips the title is **Week reviewed**.
- A versioned string-key `Application.Storage` record retains the real profile,
  missions, position, session sequence, latest 8 summaries and latest 12 changes.
  Unknown/corrupt schemas are preserved read-only; save failures roll back progress.
- Check-ins are user reports of effort, fatigue and fueling, never diagnoses.
  Significant reported fatigue offers a confirmed adjustment, without stacking
  missed training. Setup cannot overwrite a week that already has achievements
  or confirmed changes.

## Post-merge verification

On 14 November 2026, merge commit `8e6c7c1` on `dashboard-and-recovery` was checked with fresh SDK 9.1.0 production/test builds and the simulator suite: **21 passed, 0 failed, 0 errors**. PacePilot's production/test builds also succeeded. The merge leaves the main apps' source unchanged and imports their existing shared modules. See [STATUS.md](../../STATUS.md#raceforge-weekly-adventure-merge). No new screenshots or physical-watch checks were performed.

## Verification and handoff

[Final technical audit](FINAL_TECHNICAL_AUDIT.md) and [team integration handoff](TEAM_INTEGRATION_HANDOFF.md) record the current source review, reproduced/fixed plan-resizing crash, fresh 22-test results and the avatar components already embedded on the default branch.

SDK 9.1.0 normal/test builds pass on `fenix7pro_sim`. The final simulator suite
reports **22 passed, 0 failed, 0 errors**, including native storage restart at the
maximum bounded history sizes, actual BehaviorDelegate callbacks, full-week
completion and LIVE provider/session resource teardown. Raw logs stay under
ignored `bin/`; the runner's misleading exit code 1 is handled using its test summary.
Only the two inherited shell warnings remain (language resources and icon scaling).

[Milestone 3 report](MILESTONE3.md) records test results, architecture, evidence and
remaining validation. [Final setup screenshot](evidence/m3-setup.png) and the
[Gate A summit screenshot](evidence/m3-gate-a-summit.png) are actual simulator captures.
The existing [avatar replay](evidence/m2-easy-replay.mp4) documents milestone-2 art,
not an end-to-end recording of the new adventure.

Physical-watch HR/GPS acquisition, haptic feel, physical buttons and MIP smoothness
remain unverified. The simulator LIVE test exercises Garmin API paths; its values
are simulator inputs, not physical measurements. No watch-to-dashboard transport
is implemented or claimed. The weekly challenge is the only implemented journey;
race-specific journeys, respiration diagnostics and mountain styles are future work.

PacePilot now embeds the pure journey/storage model and summit renderer with its
own mission UI and result adapter. This standalone flow still owns its own app.
Further visual integration needs agreement on widget bounds and presentation. In the existing app, use its
already-running controller; do not instantiate a second one beside it. The eight
imported shared files are unchanged, and PacePilot's own build scope is unchanged.
