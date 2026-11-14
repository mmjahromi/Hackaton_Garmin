# Gut Train

A Fenix 7 Pro app for following a chosen long-session fueling plan, logging food and drink, and reflecting on gut comfort. The home screen also retains local daily activity targets and nudges.

[Current status](../STATUS.md) is the main reference for implemented features, evidence, and gaps. This README replaces the older direct-button logging and menu-pauses-workout instructions.

## Fueling flow

1. START from home opens the fuel plan. Choose **30–90 g/h** in 5 g/h steps; food category **gel, chews, drink, food**; portion **5–60 g**; drink cues **off, 10, 15, or 20 minutes**; and optional **Share live + summary**. Sharing defaults off. Confirm the plan to start.
2. Feed timing uses the selected portion and target. Hold UP/MENU to log a food portion, 150 ml drink, or gut discomfort. HR, GPS/movement, stops, climb, cadence, and wrist temperature provide context. Temperature no longer changes drink timing; the chosen interval controls it.
3. START pauses/resumes. Menus and the finish question keep the workout clock, sensors, recording, cues, and telemetry running. UP/DOWN alone do nothing during the workout. Finish requires confirmation.
4. Sessions shorter than ten unpaused minutes skip rating and local nutrition summary storage and discard the FIT recording. Previously shared live telemetry is not removed; a completion packet is still attempted.
5. Longer sessions ask for gut comfort (1–5) and an explicitly confirmed next-session target. This screen starts from the just-finished target; the earlier automatic progression helper remains in source/tests but is not used by this flow.

Qualifying LIVE sessions retain up to 20 local nutrition summaries and the first 32 timed food events per session. No on-watch history browser or sharing retry screen is implemented. Gut Train attempts a cycling FIT activity with a carbs field; saving, discard, pause/resume, and Garmin Connect delivery need physical-watch verification. DEMO and short recordings are discarded.

## Controls

| Screen | START | UP / DOWN | Hold UP / MENU | BACK |
| --- | --- | --- | --- | --- |
| Home | Open fuel plan | DOWN toggles demo | Open PacePilot; Restart programme with confirmation | Exit |
| Fuel plan | Confirm step; final step begins | Adjust value | — | Previous step; leave at first step |
| Workout | Pause/resume | No action | Log food, drink, discomfort; Resume if paused; Finish; app-switch entry requires finishing | Finish question |
| Gut rating | Confirm | Adjust 1–5 | — | Also confirms rating |
| Next-session plan | Confirm target | Adjust target | — | No action; START confirms |
| Summary / too short | Return home | No mapped action | — | Native navigation |

The task menu labels the workout running or paused. Opening or dismissing it does not change that state. LIGHT stays native. Open PacePilot from the home menu after finishing; Garmin supplies its switch confirmation. Both apps must be installed. No unfinished session transfers between them.

## Daily activity, connection, and sharing

The home screen uses local steps, active minutes, floors, weekly progress, and morning Body Battery when available. Weekly target starts at 150 minutes, adapts within 60–300, and reduces today's share for a low morning Body Battery. Background checks run every 30 minutes and can request a still-time nudge. A 200-step increase within roughly that interval is an approximate response, not measured 15-minute adherence. See [activity implementation notes](docs/stay-active.md).

Daily/background and demo-day uploads are disabled in `ActiveSync.post()`. The home DEMO banner and synthetic fallback values remain; toggling it does not publish a week to the dashboard.

Opening the app makes one `/api/watch-config?app=guttrain` request and shows the connection result. This records an app-name-only dashboard check-in even with workout sharing off; it imports no nutrition plan and is not a periodic heartbeat.

Enabled LIVE sharing sends workout telemetry and, after rating/target confirmation, a summary through the paired phone using Garmin Communications. It defaults off in every new setup. Watch DEMO workouts never upload or replace LIVE goals/history. There is no durable offline queue or user-triggered summary retry. The dashboard's nutrition storage appends summaries, so duplicate submissions are not deduplicated by session ID.

The configured dashboard is a public shared demo with no private accounts. See [connection and privacy boundaries](../STATUS.md#connection-plan-transfer-and-privacy), including stress history, five-second snapshot attempts, stale states, and best-effort completion.

## Build and run

Use Connect IQ SDK **9.1.0**, `fenix7pro` (API profile 5.2, round 260 × 260), and Garmin's official Monkey C VS Code extension. Manifest minimum API is **5.2.0**. In VS Code open this app folder, run **Monkey C: Verify Installation**, set your private key path, and match compiler type-check level 0 / Off. Root launch configurations can also run either app.

From the repository root:

```sh
./run-watch.sh gut-train-app
./run-watch.sh gut-train-app test
```

The launcher restarts the simulator; finish other simulator work first. For build-only work from this directory:

```sh
SDK="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
export JAVA_TOOL_OPTIONS=-Djava.awt.headless=true
mkdir -p bin
"$SDK/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/guttrain.prg -y "$HOME/.garmin/developer_key.der" -w -l 0
"$SDK/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/guttrain-test.prg -y "$HOME/.garmin/developer_key.der" -w -l 0 -t
```

To execute tests in an already-running simulator:

```sh
"$SDK/bin/monkeydo" bin/guttrain-test.prg fenix7pro -t
```

Compilation does not execute tests. Inspect the runner's actual summary. `release/` contains production/test PRGs and hashes; building into `bin/` does not update those copies. Sideload the production PRG into `GARMIN/APPS` using the supported USB workflow, then perform hardware acceptance. Keep signing keys private and outside shared code.

## Source map and evidence

| Responsibility | Source |
| --- | --- |
| Home, local targets, nudges, disabled day uploads | `ActiveHomeView.mc`, `HomeView.mc`, `Active.mc`, `ActiveData.mc`, `ActiveService.mc`, `ActiveSync.mc` |
| Fuel plan, clock, sensors, task menu | `NutritionSetup.mc`, `SessionView.mc`, `WorkoutClock.mc`, `Sensors.mc`, `TaskMenu.mc` |
| Rating, explicit target confirmation, summary sharing | `RatingView.mc`, `NutritionSetup.mc`, `SummaryView.mc`, `TooShortView.mc` |
| Startup check-in and live sharing | `DashLink.mc`, `LiveFeed.mc`, `StressPolicy.mc` |
| Earlier pure target rules | `Plan.mc` and its tests; automatic next-target helper is not used by current rating flow |

Latest recorded evidence is **35 simulator tests** and a simulator startup check-in reaching the dashboard. Saved debug logs are older (28 passes). The suites were not rerun for this documentation update. Native menus/buttons, screens, real sensors, haptics, FIT lifecycle, and physical-phone delivery remain unverified. Everyday meal logging exists on the dashboard only. See [STATUS.md](../STATUS.md#remaining-gaps-and-acceptance) for the full gap list.
