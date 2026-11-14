# RaceForge animated avatar prototype

An independently buildable, offline Garmin Connect IQ watch app for the Fēnix
7 Pro's 260 × 260 round display. It demonstrates an expressive athlete using
original `Graphics.Dc` artwork, four-pose running/walking animation, breathing,
sweat, a starting stance and a short celebration.

This directory is a standalone prototype intended for later integration with
PacePilot's **Features**, **Decision** and lifecycle contracts. It does not replace
PacePilot's App, View, delegates, sensors, session controller or coaching engine.
All values in the demo are synthetic and visibly labeled **DEMO**.

## Build and run

Open **this directory** in VS Code with Garmin's Monkey C extension, rather than
opening another app's manifest. Select Connect IQ SDK **9.1.0**. The watch API
profile is **5.2**. Keep your own signing key outside the repository.

```sh
cd prototypes/raceforge-avatar
bash scripts/build.sh /absolute/path/to/developer_key
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
"$sdk_dir/bin/monkeydo" bin/RaceForge.prg fenix7pro
```

The macOS build script reads Garmin's selected SDK and rejects versions other
than 9.1.0. Compilation uses **fenix7pro_sim**; simulator loading uses **fenix7pro**.
The explicit `source` and `resources` paths in `monkey.jungle` are relative to
this project. PacePilot's own source paths are unchanged and do not include it.

## Controls

| Button | Behavior |
| --- | --- |
| START | Advance the scene, wrapping after completion |
| UP | Easy replay → tempo replay → original six static poses |
| DOWN | Freeze/resume scene and animation time |
| Hold MENU | Select replay/static mode or pause/resume |
| BACK | Standard Garmin exit; returns from the menu to the demo |

Each animated scene lasts 8 seconds. The easy replay includes comfortable running,
above-target effort, easing, a flushed effort expression, walking, recovery,
ready-to-run, unavailable HR and completion. The tempo replay demonstrates that
160 bpm can be in target while the easy-run demo treats it differently. Ranges
are configurable demonstration inputs, not universal HR zones or a second coach.

## Verification after relocation

Verified **November 14, 2026**, from `prototypes/raceforge-avatar/`:

- Normal build: **BUILD SUCCESSFUL**, SDK 9.1.0, `fenix7pro_sim`.
- Test build: **BUILD SUCCESSFUL**; simulator suite: **9 passed, 0 failed, 0 errors**.
- Preserved `avatarDemoCycle` and `avatarStartDelegate` regressions.
- Animation/lifecycle, workout context, coaching authority, missing/stale HR,
  speed/stillness, replay pause, circular text clearance and offset widget tests pass.
- 600 character renders: 18,552 ms in this host simulator; retained VM memory
  unchanged at 38,520 bytes. This is not a hardware performance/battery claim.
- No duplicate avatar declarations or name collisions with the team's classes.
- Every pre-existing team file is byte-identical to the branch base.
- Relative source, manifest, layout and image resource paths compile in this location.

Reproduce with:

```sh
bash scripts/test.sh /absolute/path/to/developer_key
```

Garmin's runner returns exit code 1 even when its test summary passes. The script
checks the actual summary and reports failure if it does not show a clean pass.
Raw build/test logs are regenerated under ignored `bin/` and are not committed.
The only compiler warnings are inherited from the generated shell: no language-
specific resources declared and a 24 px launcher icon scaled to 40 px.

Physical-watch, manual button and on-device smoothness validation are **not run**.
The existing [simulator recording](evidence/m2-easy-replay.mp4) and screenshots
were captured from the original standalone milestone-2 build before relocation;
the Monkey C code is unchanged. Some captured frames omit gray captions, so
manual visual acceptance remains pending. See [the milestone report](MILESTONE2.md).

## Transfer to PacePilot later

The five reusable files are:

- `source/AvatarModel.mc` — retained presentation data.
- `source/AvatarRenderer.mc` — bounded character drawing only.
- `source/AvatarAnimator.mc` — elapsed-time animation and optional speed response.
- `source/AvatarAdapter.mc` — maps the existing snapshot/decision/lifecycle.
- `source/AvatarWorkoutContext.mc` — optional workout presentation metadata.

Keep standalone App/View/delegates, demo controller, menus and tests in this
prototype. The parent PacePilot view must own its redraws, clock and layout.
Do not copy all prototype classes into PacePilot's compilation scope.

At the inspected team base (`7b52e75`, default branch `dashboard-and-recovery`),
`FeaturePipeline` publishes `sourceStatus.hr` and `sourceStatus.speed`, matching
adapter defaults. `CoachEngine` publishes advice, reason, decisionId and
canResumeRun with matching meanings. Before embedding, coordinate widget bounds,
animation clock resets and workout-context ownership with the UI owner.
The current adapter is prepared for that work; the shared app does not yet drive it.

`fromPacePilot()` follows the supplied advice without live HR thresholds. Optional
normalized speed changes bounded visual cadence; it is not measured step cadence.
Stillness stops locomotion. Missing/not-ready/stale HR is neutral and shown as
`HR --`. No renderer sensor queries, network, persistent writes or coaching
transitions occur. The richer easy/tempo classifier is for demo presentation only.

See [PROJECT.md](PROJECT.md), [AGENTS.md](AGENTS.md) and [MILESTONE2.md](MILESTONE2.md)
for design, contracts, limitations and the detailed integration call pattern.
