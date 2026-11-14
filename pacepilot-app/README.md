# PacePilot

Offline, experimental run/walk coaching for Garmin Fenix 7 Pro. The default goal is 20 unpaused session minutes. Walking counts toward the goal. Estimated moving time is tracked separately. The illustrative HR band is 120–140 bpm and must be explicitly confirmed or adjusted before each session.

## The problem

An everyday runner can set out for an easy session and find the effort rising on a hill or after several minutes. A heart-rate number alone leaves them to decide when to ease off, walk, or try running again. Walking can also feel like abandoning the session.

PacePilot turns sustained effort into one clear suggestion on the wrist. Running and walking both count toward a manageable session goal. The user can request a walk, pause, or end at any time.

## What the prototype achieves

- Suggests **Run easy**, **Ease off**, **Walk break**, or **Try running?** from sustained HR evidence.
- Uses a manually chosen HR band, with a default 20-minute unpaused session goal.
- Smooths brief HR spikes and requires fresh evidence after signal loss or resume.
- Combines qualified GPS speed and accelerometer evidence to estimate movement.
- Adds “Climb likely” context when a sustained pressure trend qualifies.
- Shows missing, stale, unsupported, and failed sensor states.
- Saves the latest 20 local LIVE session summaries with session time, estimated moving time, unknown-motion time, HR coverage, and walk-prompt count.
- Runs a reproducible, clearly labeled demo through the same filtering and coaching rules.

The intended benefit is making an easy run/walk session easier to understand and finish. User benefit and long-term habit change have not yet been measured.

### How a suggestion changes

| Condition | App response |
| --- | --- |
| HR stays above the selected upper bound for 15 seconds | Suggest Ease off |
| High HR continues for 60 seconds | Suggest Walk break |
| At least 60 seconds in the walk state, with HR at or below the recovery threshold for 30 seconds | Offer running again, provided movement is not explicitly STILL |
| The user accepts a valid offer with UP | Return to Run easy |
| HR is missing or still reacquiring | Show HR unavailable; walk if needed |
| START pauses the session | Freeze goal progress and coaching timers |
| The unpaused goal is reached | Show completion and the summary |

The recovery threshold is the chosen upper HR bound minus 5 bpm. UNKNOWN movement permits an offer with uncertainty displayed. The example HR band is illustrative and requires explicit confirmation or adjustment.

## Quick demo

1. Load the app into the Fenix 7 Pro simulator using the VS Code steps below.
2. On Choose mode, press DOWN to select Replay standard.
3. Press START through the HR band, goal, energy, soreness, today’s goal choice, and sharing screens. Sharing defaults off.
4. At Confirm settings, press START again.
5. Watch the **DEMO 4x** sequence finish in about 45 real seconds.

| Virtual time | Expected action |
| --- | --- |
| 36 seconds | Ease off |
| 81 seconds | Walk break |
| 141 seconds | Offer running |
| 160 seconds | Scripted acceptance returns to Run easy |
| 180 seconds | Goal met |

The replay uses a three-minute virtual goal. The user-acceptance event at second 160 is scripted for the demonstration. Choose Replay HR loss to see missing-data behavior.

## Run in Visual Studio Code

### 1. Install the tools

1. Install Visual Studio Code and Garmin's official **Monkey C** extension, identifier `garmin.monkey-c`.
2. Install Garmin Connect IQ SDK Manager. Install and select **SDK 9.1.0**, the version used for this build.
3. Install the **Fenix 7 Pro** device package, identifier `fenix7pro`.
4. Open the Command Palette with Cmd+Shift+P on macOS or Ctrl+Shift+P on Windows/Linux.
5. Run **Monkey C: Verify Installation** and resolve any reported Java, SDK, or signing-key setup issue.

The command names and launch configuration below were checked against the locally installed Garmin Monkey C extension 1.1.3. SDK setup is described in [Garmin's getting-started guide](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/).

### 2. Open the correct folder

For a fresh checkout:

```sh
git clone --branch dashboard-and-recovery https://github.com/mmjahromi/Hackaton_Garmin.git
cd Hackaton_Garmin/pacepilot-app
code .
```

Alternatively, use **File > Open Folder** and select `pacepilot-app` inside your existing checkout. The VS Code folder root should contain `manifest.xml` and `monkey.jungle`. The repository contains multiple prototypes, so opening this specific folder selects PacePilot's build configuration.

### 3. Set your signing key

Run **Monkey C: Generate a Developer Key** if you need a key. Keep it outside the repository. In VS Code User Settings, set **Monkey C: Developer Key Path** to your own key's absolute path.

For this Mac, the existing key is `~/.garmin/developer_key.der`; expand `~` to the full user path in the VS Code setting. Each teammate should use their own local path.

Set **Monkey C: Type Check Level** to **Off** for this project's dynamic dictionaries, matching the verified `build.sh` compiler setting. Keep **Monkey C: Jungle Files** set to `monkey.jungle`.

### 4. Add launch configurations

If VS Code has not generated a Monkey C launch configuration, create `.vscode/launch.json` inside `pacepilot-app` with:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "monkeyc",
      "request": "launch",
      "name": "Run PacePilot",
      "device": "fenix7pro",
      "stopAtLaunch": false
    },
    {
      "type": "monkeyc",
      "request": "launch",
      "name": "Test PacePilot",
      "device": "fenix7pro",
      "runTests": true
    }
  ]
}
```

### 5. Build and launch

1. Open **Run and Debug** in VS Code.
2. Select **Run PacePilot** and press **F5**.
3. Select Fenix 7 Pro if the extension requests a device.
4. Wait for compilation and the Connect IQ simulator to open.
5. Use the simulator's watch buttons to complete setup and start LIVE or DEMO.

You can also run **Monkey C: Build Current Project** from the Command Palette. For a device-targeted build, use **Monkey C: Build for Device** and choose `fenix7pro`.

### 6. Run the unit tests

Select **Test PacePilot** in Run and Debug and press F5, or run **Monkey C: Run Tests** from the Command Palette and select the Fenix 7 Pro target when prompted.

Read the test output in VS Code's Debug Console/Output panels. The verified baseline is **29 passed, 0 failed, 0 errors**. These tests run the production Monkey C filtering, engine, controller, storage boundaries, and rendering/control paths.

The VS Code UI workflow is documented from the installed extension's commands and schema. The observed build/test results were obtained through the SDK command-line tools; the VS Code UI workflow itself has not been exercised in this session.

### Troubleshooting

| Symptom | Check |
| --- | --- |
| Missing SDK or Java | Run Monkey C: Verify Installation and select SDK 9.1.0 in SDK Manager |
| Fenix 7 Pro unavailable | Install the `fenix7pro` device package |
| Signing-key error | Set your own absolute developer-key path and confirm the file exists |
| Wrong app builds | Open `pacepilot-app` as the VS Code folder root |
| Simulator stops accepting loads | Close the simulator fully, reopen it, and launch again |
| LIVE shows unavailable readings | Sensor availability depends on the device/simulator inputs; choose the labeled replay for deterministic testing |
| App is waiting in setup | Advance all settings with START, then confirm on the final screen |
| Type-check errors with a different workspace configuration | Match this project's verified Type Check Level Off setting |
| macOS shell script fails on another OS | Use the VS Code workflow or invoke the installed SDK's platform-specific compiler/runner scripts |

## Build and run from a terminal

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
| Setup | UP/DOWN adjusts mode, HR band, goal, energy, soreness, today’s goal choice, and optional sharing. START advances. BACK returns to the previous setting. The final START confirms and starts. |
| Active | START pauses. UP/DOWN switches the metrics page. Hold UP opens tasks: Walk now, Accept running (only when offered), Finish workout. BACK opens end confirmation with Cancel selected. |
| End confirmation | UP/DOWN chooses Cancel or End. START confirms. BACK cancels. Coaching continues until confirmed. |
| Paused | START resumes with fresh HR acquisition. BACK opens end confirmation. |
| Complete | Confirm effort, next goal, and a routine with START; UP/DOWN changes choices. Then UP/DOWN switches summary pages and START returns. The task menu offers Retry sharing. |
| History | Hold UP from setup and choose Local history; UP/DOWN browses and START returns. |
| Extra metrics | UP/DOWN during an active session toggles speed and estimated moving time. This optional page is unnecessary for any core control. |

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
- SummaryStore persists schema-v1 config and the latest 20 LIVE summaries using string keys. DEMO never replaces it.
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
- Up to 20 local LIVE summaries are retained. An unsuccessful write is shown as unsaved on the second summary page.
- No route history, medical zone estimation, or automatic escalation of next-session goals.

See TEST_RESULTS.md for observed evidence and DEMO.md for the pitch.

## Recovery and shared dashboard

Before a session, report energy and soreness. Low energy or high soreness preselects a shorter option; you review and confirm it. Afterward, choose Easy, About right, Too hard, or Skip rating; then confirm Repeat goal, Five minutes shorter (minimum one minute), or Choose later. An easy rating never automatically increases your goal. Meal, drink, or rest routines are optional on-screen cues, not scheduled notifications or inferred nutritional requirements.

Sharing defaults off for each session. When enabled, the completed LIVE summary and confirmed feedback are sent through Garmin Communications to `https://gut-train-web.vercel.app/api/pace-sessions`. DEMO never uploads or changes saved goals. Coaching and local history work offline. A failed upload is shown on the summary; open the task menu there and choose Retry sharing. There is no background upload queue.

The dashboard combines both apps but does not pair users or remotely change watch goals. It is a public hackathon demo: anyone with its URL can read shared summaries. Keep sharing off for private sessions. Local history is retained if connectivity fails. The companion source and running instructions are in `../gut-train-web/README.md`.

## Button and heart-rate feedback revision

During a workout START/STOP stops or resumes the timer. Setup, feedback, and native menus retain Garmin’s standard START-to-select behavior. Hold UP/MENU opens task choices. The LIGHT button remains managed by Garmin and respects device settings. No flashlight or physical sensor LEDs are repurposed.

The existing workout screen shows a green progress arc when fresh filtered HR is within the chosen band, yellow within 5 bpm outside it, and a slowly pulsing red (high) or yellow (low) arc farther outside. Missing or reacquiring HR is gray. These are descriptive bands, not clinical classifications. Text identifies the action even without color. Existing high-HR coaching/haptics retain their sustained-evidence rules. A low-band episode lasting 15 real seconds can produce one cue to check effort; it never instructs an automatic increase in intensity.

The task menu can open Gut Train from setup or after completed feedback. Switching during an unfinished workout requires ending it first; it does not carry a running workout into the other app. Garmin’s System.exitTo presents its own confirmation and handles launch. A missing app shows an installation message.

The visual redesign is intentionally reserved for Claude; see `../CLAUDE_HANDOFF.md`.

## Live workout feed (current revision)

Enable **Share live + summary** during watch setup, then start a LIVE session with the paired phone connected to the Internet. This explicitly shares heart rate and workout metrics to the public demo. It defaults off. DEMO sessions remain local in the watch builds; API tests use labeled synthetic packets only against isolated/local storage.

Each watch uploads at most one normal snapshot every 5 seconds, with immediate status-change attempts and a single request in flight. The dashboard live panel polls every 2 seconds. This is near-live HTTP telemetry via Garmin Communications, not a guaranteed low-latency socket. Slow Bluetooth/phone/network connections can delay updates. No raw GPS coordinates are uploaded.

PacePilot sends filtered HR when ready, elapsed time, goal, estimated moving time, speed, and active/paused/completed state. Gut Train sends HR, elapsed time, distance, speed, logged carbs/fluids, and state. Paused/completed packets carry no current HR. The dashboard shows the last120 snapshots (about 10 min at the nominal rate); gaps are not interpolated. After 20 sec without a fresh sample it marks the stream stale and stops presenting old HR as current. End delivery is best effort: if connectivity is lost while ending, the dashboard becomes stale rather than inventing completion.

The API keeps the newest session per app/mode for up to 24 h, with atomic Redis ordering checks to ignore duplicate, delayed, or post-completion packets. This is a shared hackathon feed, not multi-user private tracking. Existing summaries remain separate. The new watch binaries must be installed; deploying the website does not update the watch.
