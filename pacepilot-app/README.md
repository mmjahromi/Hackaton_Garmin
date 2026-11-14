# PacePilot

An experimental Fenix 7 Pro run/walk coach. Walking counts toward a manageable unpaused session goal. The default goal is 20 minutes and the illustrative HR band is 120–140 bpm. Review the band and goal before starting.

[Current status](../STATUS.md) is the main reference for features, verification evidence, shared-dashboard behavior, and remaining gaps. This README describes current setup and controls, including the weekly adventure integrated after merge `8e6c7c1`.

## Workout behavior

Fresh filtered HR above the selected upper bound for 15 seconds suggests **Ease off**; 60 seconds suggests **Walk break**. After at least 60 seconds walking and 30 seconds at or below the recovery threshold (upper bound minus 5), the app can offer **Try running?**. Accept through the task menu. Explicit STILL movement blocks the offer; missing/reacquiring HR disables it.

The feature pipeline combines wrist HR, qualified GNSS speed, accelerometer movement evidence, and pressure-trend context. It reports missing/stale/unsupported/error states. HR feedback uses text, band colors, slow pulsing, and vibration with cooldown. Low HR alone does not request more effort.

The integrated RaceForge avatar follows the coaching decision and lifecycle. It adds presentation only. A separate 250 ms redraw timer runs on the visible active avatar page; menus, metrics, pause, completion, and hide stop it without stopping the workout clock. Device readability, smoothness, memory, and battery cost remain unverified.

## Startup, plans, and sharing

Opening PacePilot shows its icon and **START to open**. UP/DOWN and MENU do nothing there; BACK exits. No request is sent until START activates the app. Activation requests `/api/watch-config?app=pacepilot`, recording an app-name-only check-in. A shared real plan is displayed when dashboard **Send plan to watch** consent is enabled. A successful response without an available plan triggers a labeled demo-plan request. A connection failure shows a message; the app remains usable offline.

START accepts a usable offer for this session; BACK dismisses it. A demo plan remains labeled, and its ID is never submitted as a real plan completion. Plan provenance and workout mode are separate: accepting a demo plan does not switch a LIVE workout into DEMO. The imported goal is capped at 60 minutes, even though the dashboard can suggest 90; activity labels do not switch the coaching engine to a different sport. The saved goal is unchanged by accepting a plan.

Workout sharing defaults off and resets after each session. UP/DOWN on the short review toggles **Live sharing**. Enabled LIVE sessions send telemetry and a completed summary through Garmin Communications and the paired phone. DEMO workouts suppress uploads. The shared dashboard is public; no private account or device association exists. The activation check-in occurs even when workout sharing is off.

After a workout, confirm effort, next goal, and an optional routine. The latest 20 LIVE summaries are stored locally. Failed summary sharing can be retried from the task menu after feedback. There is no durable offline upload queue. FIT recording remains disabled in PacePilot.

## Fueling during a PacePilot workout

The workout menu logs **150 ml drink** and **25 g carbs** without pausing; totals appear on the metrics page. The home menu's **Drink reminders** cycles Auto, Off, every 10, 15, or 20 minutes. Auto uses 15-minute cues only for goals of at least 45 minutes. A due cue uses the small top line ("Drink. MENU to log") and attempts one vibration through the existing alert gate, preserving the coach's instruction. Logging a drink clears the cue and resets its interval. The reminder mode is held in memory for this app launch.

With sharing enabled, totals are included in live packets and the completed summary; Today shows totals logged in completed workouts from either app. This is fixed-portion workout logging, not the dashboard's everyday calorie log or Gut Train's configurable fueling program. Food/drink totals are added after the local summary save and are not persisted by the local-history schema.

## Controls

| Screen | START | UP / DOWN | Hold UP / MENU | BACK |
| --- | --- | --- | --- | --- |
| Opening screen | Activate and request dashboard plan | No action | No action | Exit |
| Startup / today's plan | Use a usable offer; dismiss an unavailable-plan message | No setting change | Tasks | Dismiss and keep own goal |
| Home | Open review | No setting change | Weekly adventure, Get today's plan, Change settings, Drink reminders, Local history, Open Gut Train | Exit |
| Short review | Begin workout | Toggle live sharing | Tasks | Home |
| Change settings | Next step; final confirmation starts | Adjust mode, HR band, duration, check-ins, goal choice, sharing | Tasks | Previous setting |
| Workout | Pause/resume | Switch metrics page | Log drink, Log food, Walk now, Accept running when offered, Finish, Metrics | Finish question, Cancel preselected |
| Finish question | Confirm selected choice | Cancel / End | — | Cancel |
| Completed | Confirm feedback; then return | Adjust feedback or summary page | Retry sharing; Open Gut Train after feedback | Summary/navigation behavior |
| Local history | Return | Browse records | — | Return |

Opening a workout menu or finish question leaves the workout running. START controls pause/resume. LIGHT retains Garmin's native behavior. App switching requires the other app to be installed and the current workout finished; Garmin supplies its confirmation. No active session is transferred between apps.

## Weekly adventure in PacePilot

Hold UP/MENU from home → **Weekly adventure**. The selected LIVE/DEMO workout mode also selects the journey: LIVE has saved progress; DEMO has a separate temporary trail. First use asks for baseline, available days (3–5), activity preference, and daily time. These generate a gentle week with three/four timed missions and a final summit check-in. Days are relative 1–7, without automatic calendar rollover.

START opens the trail, then previews the highlighted mission. UP/DOWN browses. START on the next timed mission opens PacePilot's existing review with that mission's duration; the current HR band and sharing switch remain visible. BACK cancels without credit. Walking/recovery missions do not offer running, and mobility uses a resting avatar. These are timed missions, not verified movement or technique assessments.

The workout uses the same controller, sensors, avatar, pause/menu rules, drink reminders, food/drink logs, LIVE sharing, and post-workout recovery feedback as a normal PacePilot session. Confirming the final feedback answer records the mission result. A full goal awards one checkpoint; ending early saves a partial result without advancing. Save failures roll progress back and keep the result available for START to retry. DEMO results never update the saved LIVE week.

The summit is an explicit weekly check-in after the remaining missions. From the trail, MENU offers changes to the next mission: mark missed, shorten an optional mission, move to a free available day, or skip. Every proposal requires confirmation; earlier achievements stay. Personalization is available only before a week has started. BACK exits an unfinished setup without creating progress.

Journey data uses versioned local `pacepilot.weekly.v1` storage, with eight results and twelve changes retained. Unknown/corrupt saved records are preserved rather than overwritten. Progress survives app restart after a successful save; an interrupted in-progress workout is not restored. It does not import the separate RaceForge app's private storage. Workout summaries and live metrics still reach the existing dashboard when sharing is enabled; the weekly trail itself is local and has no dashboard sync yet. No second app or workout controller is required.

## Build and run

Use Connect IQ SDK **9.1.0**, Garmin's official Monkey C VS Code extension (`garmin.monkey-c`), and the `fenix7pro` device package (API profile 5.2, 260 × 260). Manifest minimum API is 3.2.0; runtime capability checks still matter.

In VS Code, open this folder, run **Monkey C: Verify Installation**, configure your private developer-key path, and use `monkey.jungle`. Type Check Level **Off** matches the project's dynamic dictionaries and compiler `-l 0` setting. The root workspace also has launch configurations for both apps.

From the repository root:

```sh
./run-watch.sh pacepilot-app
./run-watch.sh pacepilot-app test
```

This builds and starts a fresh simulator, interrupting any existing simulator run. For build-only work from this directory:

```sh
./build.sh
```

`build.sh` compiles production and test PRGs into `bin/`; it does not execute tests. Defaults use the SDK selected by `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg` and the key at `~/.garmin/developer_key.der`. Override with `CONNECT_IQ_SDK` and `GARMIN_DEVELOPER_KEY`. Keep keys outside the repository.

For an already-running simulator:

```sh
sdk_path="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
"$sdk_path/bin/monkeydo" bin/pacepilot.prg fenix7pro
"$sdk_path/bin/monkeydo" bin/pacepilot-test.prg fenix7pro -t
```

Inspect the printed test summary; compilation is not test execution, and launcher exit codes can be misleading. Ready-to-sideload artifacts and fingerprints are under `release/`. Sideload the production PRG into the physical watch's `GARMIN/APPS` using Garmin's supported USB workflow. Building or deploying the website does not update the watch.

The full repository is needed to build: `monkey.jungle` imports RaceForge's pure journey/storage modules and summit renderer by explicit paths, without its standalone app or workout bridge.

## Demo and implementation map

For the standard replay, press START on the opening screen, dismiss the startup offer, hold UP → Change settings, choose Replay standard, review the band/check-ins/sharing, and confirm. **DEMO 4x** uses a three-minute virtual goal and finishes in about 45 real seconds. The standard fixture eases at virtual second 36, walks at 81, offers running at 141, scripts acceptance at 160, and completes at 180. Replay HR loss exercises signal loss and reacquisition. See [DEMO.md](DEMO.md).

| Responsibility | Source |
| --- | --- |
| Setup, plan acceptance, timers, feedback, task routing | `source/PacePilotApp.mc`, `PlanOffer.mc`, `TaskMenu.mc`, `Delegate.mc` |
| Sensor acquisition, freshness/filtering, coaching, lifecycle | `LiveProvider.mc`, `Features.mc`, `CoachEngine.mc`, `SessionController.mc` |
| Display, avatar, HR bands, haptics | `Presenter.mc`, `AvatarBridge.mc`, `Avatar*.mc`, `HrFeedback.mc`, `AlertService.mc` |
| Local storage and public sharing | `SummaryStore.mc`, `DashboardSync.mc`, `LiveFeed.mc`, `StressPolicy.mc` |
| Weekly mission UI and session-result adapter | `Weekly.mc`, shared `WeeklyJourney.mc`, `JourneyStorage.mc`, `SummitRenderer.mc` |
| Drink timing and fixed-portion workout logs | `Fuel.mc`, `PacePilotApp.mc` |
| Deterministic replay and contracts | `ReplayProvider.mc`, `Config.mc`, `Contracts.mc`, `fixtures/replay.json` |

Current integration verification: **80/80 simulator tests pass**, with production/test builds successful on SDK9.1.0 / fenix7pro. The [current raw log](tests/weekly-simulator-results.txt) includes mission integration, rendering-call, completion/partial, persistence/rollback, cancellation and DEMO regressions plus all earlier coaching tests. Release PRGs and fingerprints were refreshed. Earlier debug logs and commit counts are historical. Physical watch/phone and actual screen/button acceptance remain open. See [STATUS.md](../STATUS.md#current-integration-verification) and [TEST_RESULTS.md](TEST_RESULTS.md).
