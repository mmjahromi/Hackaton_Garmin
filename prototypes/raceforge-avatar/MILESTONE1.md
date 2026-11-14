# RaceForge avatar — milestone 1

Implemented with SDK 9.1.0, compiler target `fenix7pro_sim`, simulator device
`fenix7pro` (260 × 260 round MIP, API 5.2). The generated App, View, Delegate,
MenuDelegate and resource names are preserved. No permissions were added.

START (upper-right button) advances this repeating, static sequence:

| Phase | Pose / expression | Headline | Synthetic HR display |
| --- | --- | --- | --- |
| 1 | Upright, smiling, waving | START MISSION | HR -- |
| 2 | Forward lean, bent running stride, pumping arms | NICE & EASY | HR 130 |
| 3 | Lower head, lowered arms, angled brows, open mouth and puff | EASE OFF | HR 150 |
| 4 | Longer walking stance, loose arms, puff and sweat drop | WALK BREAK | HR 130 |
| 5 | Upright smile and raised thumb | READY? YOUR CHOICE | HR 130 |
| 6 | Raised arms, happy eyes and two sparkles | MISSION COMPLETE | HR -- |

The DEMO badge is always visible. All numbers are synthetic presentation inputs.
BACK uses the normal Garmin root-view exit behavior. No animation timer, replay,
sensor acquisition, advice engine, haptics, persistence or network is implemented.

## Build and run

Use the existing developer signing key outside this folder. Do not commit it.
The build script reads Garmin's selected SDK and rejects any version other than
9.1.0. From the project directory:

```sh
bash scripts/build.sh /absolute/path/to/developer_key
sdk_dir="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_dir/bin/connectiq"
"$sdk_dir/bin/monkeydo" bin/RaceForge.prg fenix7pro
```

`fenix7pro_sim` is the compiler target; `monkeydo` requires `fenix7pro`.
Passing the `_sim` suffix to the runner stalled in this environment.
The output is `bin/RaceForge.prg`; logs and generated files are ignored by Git.
Both shell and avatar compile successfully. The untouched shell's two warnings
remain: no language-specific resources declared and launcher icon scaled 24→40 px.

## Simulator checks

```sh
bash scripts/build.sh /absolute/path/to/developer_key --test
"$sdk_dir/bin/monkeydo" bin/RaceForge-tests.prg fenix7pro -t
```

On November 14, 2026 the SDK simulator reported:

```text
avatarDemoCycle                     PASS
avatarStartDelegate                 PASS
Ran 2 tests
PASSED (passed=2, failed=0, errors=0)
```

Full local output: `bin/simulator-tests.log`. Tests render all six poses using
native Garmin buffered contexts, repeat the sequence three times, exercise an
offset 72 × 84 widget, check headline width, invoke the actual START delegate
18 times and draw again after hide/show. Tests are annotated `(:test)` and are
excluded from the normal build. The SDK runner returned exit code 1 despite
the passing summary; inspect its actual test output.

The first test run caught a `clearClip()` runtime error on a buffered context;
the renderer now resets the clip with `setClip(0, 0, dc.getWidth(), dc.getHeight())`.

Manual visual review and physical button input remain pending: macOS denied
assistive access for simulator automation and desktop screenshot capture failed.
No simulator screenshot or hardware validation is claimed. For manual review,
press START six times, check every expression/headline and circular-edge clearance,
then BACK and relaunch. No timer exists, so there is no hidden animation work.

## Reuse in PacePilot

Transfer `source/AvatarModel.mc` and `source/AvatarRenderer.mc` only for this
milestone. They define `RaceForgeAvatarModel` and `RaceForgeAvatarRenderer`.
The model contains `pose`, `headline`, `hrText`, `modeText`. The renderer draws
only the character, scales uniformly, clips to the requested rectangle and does
not clear it. The parent owns clearing, captions, mode badge, redraws and navigation.
It resets the Dc clip to the full context and pen width to 1; the parent must
reapply its own clip, colors and pen before further drawing if needed.

Proposed call pattern (adapter pseudocode, not yet implemented):

```text
avatarIntegrationExample(dc, features, decision, lifecycle):
    model = agreedAdapter.fromSnapshot(features, decision, lifecycle, 0)
    parent clears its avatar widget and draws its instruction + mode label
    renderer.draw(dc, model, left, top, width, height)
    parent requests redraw only when needed
```

Coordinate the adapter signature and widget bounds with UI owner C before merge.
The shared architecture PDF was unavailable locally; request the current shared
contract before the final merge. No teammate code was changed. Paused, missing-HR
adapter behavior, live Decision integration, animation and timed replay are later
milestones. The static demo does not infer advice or actual fatigue from HR.
