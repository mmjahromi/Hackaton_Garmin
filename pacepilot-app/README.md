# PacePilot

Offline, experimental run/walk coaching for Garmin Fenix 7 Pro. The default goal is 20 unpaused session minutes. Walking counts toward the goal. Estimated moving time is tracked separately. The illustrative HR band is 120–140 bpm and must be explicitly confirmed or adjusted before each session.

## Build and run

Verified compiler: Connect IQ SDK 9.1.0. Installed device identifier: `fenix7pro`, round 260 × 260, device profile API 5.2. Manifest minimum API: 3.2.0. Runtime capabilities are checked where needed. No network or phone dependency.

From this directory:

```sh
./build.sh
sdk_path=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
"$sdk_path/bin/connectiq"
"$sdk_path/bin/monkeydo" bin/pacepilot.prg fenix7pro
```

Set `CONNECT_IQ_SDK` and `GARMIN_DEVELOPER_KEY` to override the local SDK/key locations. The default signing key is `~/.garmin/developer_key.der`. Keep keys private. The build script uses dynamic Monkey C dictionaries and compiler type-check level 0.

Run the actual Monkey C unit tests:

```sh
"$sdk_path/bin/monkeydo" bin/pacepilot-test.prg fenix7pro -t
```

Inspect the printed PASSED/FAILED summary. The SDK launcher can have host-specific exit codes. Build outputs are `bin/pacepilot.prg` and `bin/pacepilot-test.prg`.

For sideloading, use Garmin's supported USB transfer workflow to copy `bin/pacepilot.prg` into `GARMIN/APPS` on the actual Fenix 7 Pro. Eject safely, open PacePilot, and complete T12 in TEST_RESULTS.md. A build or simulator test does not verify physical deployment.

## Controls

| Screen | Controls |
| --- | --- |
| Setup | UP/DOWN adjusts mode, HR low, HR high, or goal. START advances. BACK returns to the previous setting. The final START confirms and starts. |
| Active | START pauses. DOWN requests a walk break. UP accepts running only when readiness is offered. BACK opens end confirmation with Cancel selected. |
| End confirmation | UP/DOWN chooses Cancel or End. START confirms. BACK cancels. Coaching continues until confirmed. |
| Paused | START resumes with fresh HR acquisition. BACK opens end confirmation. |
| Complete | UP/DOWN switches summary pages. START returns to setup. |
| Extra metrics | Hold UP during an active session to toggle speed and estimated moving time. This optional page is unnecessary for any core control. |

Mode choices are LIVE, standard DEMO 4x, and HR-loss DEMO 4x. All demo screens are explicitly marked. Demo uses a 180-second virtual goal and four sequential one-second updates per real timer tick. The standard fixture automatically sends the explicit ACCEPT_RUN event at virtual second 160 to complete its scripted demonstration.

Source badges: `ok` = valid, `--` = missing/acquiring, `old` = stale, `n/a` = unsupported, `err` = failed. In DEMO all source values are synthetic even when the badge says valid.

## Implementation

- Contracts and Config define schema-v1 values, units, null handling, and input bounds.
- LiveProvider owns wrist HR, qualified GNSS speed, raw accelerometer reduction, pressure, and idempotent teardown.
- ReplayProvider produces deterministic raw frames for the same FeaturePipeline and CoachEngine used in LIVE.
- FeaturePipeline owns per-channel freshness, unique-timestamp sampling, HR median/reacquisition, movement fusion, and pressure-trend evidence.
- CoachEngine contains pure effort rules and one-transition-per-tick decisions.
- SessionController owns lifecycle, event precedence, goal accounting, pause/resume, bounded transition records, and completion.
- Presenter reads state and formats the round display. Font measurement bounds text to the circular screen. Delegate translates controls.
- AlertService deduplicates transition haptics with a ten-real-second cooldown.
- SummaryStore persists schema-v1 config and the last LIVE summary using string keys. DEMO never replaces it.
- Tests exercise the production Monkey C classes directly in the target simulator.

## Limitations and disabled features

- No physical watch was mounted during implementation. Live sources and T12 remain unverified on hardware.
- Visual readability and physical button/haptic behavior have not been inspected by eye. Rendering/control tests use a drawing probe; it checks rendering execution and control state, not actual pixels.
- FIT recording is deliberately disabled pending device lifecycle verification. There is no Fit permission and no Garmin Connect save claim.
- Experimental HR thresholds and motion/pressure heuristics are engineering choices. They do not diagnose fatigue, dehydration, or clinical recovery.
- A pressure trend may reflect weather or airflow. GPS speed may have mixed provenance; quality checks qualify its use.
- Raw sensor timestamps record callback reception, so an internal device sensor stall may be undetectable.
- The HR-loss replay suppresses readiness until fresh acquisition and rule holds qualify again. It does not promise the standard replay's recovery timestamp.
- A tick gap over two seconds credits no elapsed time. Resuming requires fresh post-resume HR samples.
- Only one local LIVE summary is retained. An unsuccessful write is shown as unsaved on the second summary page.
- No cloud dashboard, route history, medical zone estimation, or automatic escalation of next-session goals.

See TEST_RESULTS.md for observed evidence and DEMO.md for the pitch.
