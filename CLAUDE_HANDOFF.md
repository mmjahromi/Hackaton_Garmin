# Claude handoff: PacePilot + Gut Train

## User intent and constraints

User requests a Garmin hackathon product: two watch apps, one dashboard, nutrition/recovery flows, predictable buttons, task menus, HR color/pulse/haptic guidance, and switching apps from the menu. Latest instruction explicitly reserves the visual redesign for Claude. They want Apple Watch/Garmin-like clarity, but the target is a round Fenix 7 Pro 260×260 MIP display with five physical buttons. Do not copy Apple-specific gestures onto this device.

**No screenshots or screen capture:** user explicitly refused permission. Use CLI, source, and nonvisual tests. Do not commit signing keys, root developer_key, credentials, .env, node_modules, .next, or .vercel. No physical-watch verification has happened. Current simulator test logs pass; do not treat them as physical-watch or visual acceptance.

## Workspace and git

Main edited workspace: `/Users/alokiksinghkinra/Desktop/untitled folder/HACKATHON NOV 2026` (not itself a git repo).
Git checkout: `/tmp/hackathon-garmin-branch.JajFUQ`.
Repo: https://github.com/mmjahromi/Hackaton_Garmin
Branch: `dashboard-and-recovery`.
Previous nutrition/recovery commit: `50e15a3`; button-feedback revision follows it. Run git log/status to find the latest commit. Changes are copied from the main workspace into the checkout. Never overwrite unrelated prototype folders. Back up before broad edits.

Production dashboard: https://gut-train-web.vercel.app . It was deployed for the nutrition/recovery revision. Current button changes are watch-only; no new web deployment was needed. GitHub push and Vercel deployment are separate operations in this workflow.

## Implemented

### PacePilot

`source/PacePilotApp.mc`: session lifecycle, setup (mode, HR band, goal, energy/soreness, today's goal choice, sharing), post-session effort/next goal/routine confirmation. START stops/resumes the workout clock. Setup/menu START still selects, as Garmin expects. UP/DOWN changes metrics in the workout.

`source/TaskMenu.mc` + view.menu/task: native Menu2 task choices, history, walk now, accept running only when offered, finish confirmation, sharing retry, app switching. Menu is hold UP on target device. Switching to Gut Train uses `manifest-id://eb469543-a0a5-4bc4-b337-b8361a381f06`; it is available from setup or after complete feedback. An unfinished workout cannot silently switch away.

`source/HrFeedback.mc`: fresh filtered HR within configured bounds = green; <=5 bpm outside = yellow; >5 bpm high = pulsing red; >5 bpm low = pulsing yellow; missing/reacquiring = gray. Slow one-second alternating emphasis is screen color, not physical LEDs or flashlight. Low-band cue after 15 real seconds says check effort, never automatically push harder. High-HR sustained coaching and vibration logic remain in CoachEngine/AlertService. Existing haptic cooldown remains in effect.

`Presenter.mc`: only functional indicator color/text and navigation labels were added. A full visual redesign has NOT been done.

### Gut Train

`source/NutritionSetup.mc`: chosen target 30–90 g/h, food category, portion 5–60 g, drink reminder interval, opt-in sharing. Summary target is explicitly confirmed rather than automatically increased. Stores 20 nutrition summaries; logs first 32 food events with time/portion/type.

`source/SessionView.mc`, `WorkoutClock.mc`: START stops/resumes. Excludes stopped time from nutrition clock, stops sensor sampling and FIT recording while paused, resumes on START. UP/DOWN or hold UP/MENU opens native tasks and stops the workout. Dismissal leaves it stopped. Log food/drink/discomfort through the menu; Finish uses confirmation. Recheck recording.stop/start behavior on hardware.

`source/TaskMenu.mc`: home menu opens PacePilot or reset confirmation. Intent URI `manifest-id://b21a5430-b50f-4e08-aca5-a95ab210aec8`. Workout must be finished before switching. Missing app shows install message. Gut Train does not yet use PacePilot's configurable colored HR bands; it retains its existing high-HR feeding cue.

LIGHT is intentionally untouched in both apps: Garmin handles native backlight behavior and timeouts. Do not intercept it to flash the flashlight.

### Dashboard and privacy

`gut-train-web/app/SharedDashboard.js`: Overview, Recovery, Nutrition tabs; polls both summary endpoints every 5 sec. The older Nutrition component additionally polls its own endpoints every 2 sec. This is completed-summary refresh, NOT a live HR stream. No during-workout telemetry was added. Watch summaries upload only after explicit per-session opt-in; defaults off. DEMO does not upload. Daily/background uploads were disabled in ActiveSync to remove unconsented publication.

`/api/pace-sessions`: schema-v1 validation, optional feedback, idempotency by mode/sessionId, max200. `/api/sessions`: nutrition logs/confirmed plan. Existing Redis env vars or in-memory fallback. Public shared hackathon site, no user accounts or private read authentication. No secure multi-user association and no watch plan push from dashboard. Do not add HR streaming without a separate explicit sharing choice and clear live/stale/session timestamps.

## Verification

SDK 9.1.0, fenix7pro profile, Java headless, compile type level0. Both production/test PRGs compile. Current suites: PacePilot33, Gut Train25. New tests cover band boundaries, unknown HR, pulse vs steady, low-band dwell/reset, and pause clock exclusion. Initial simulator launch errors/timeouts were resolved during retries: **all33 PacePilot and25 Gut Train tests pass**. Current logs are `tests/controls-simulator-results.txt` under each app. Old baseline logs with29/22 passes apply to older code only. No physical or visual acceptance.

Dashboard44 tests pass; production build and local/live HTTP200 checks passed in nutrition/recovery revision. Current watch-only work reran the44 tests. Build commands are in app READMEs. Production/test PRGs and SHA256 fingerprints are under each app's release folder.

SDK path: `cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"`.
Signing key: `$HOME/.garmin/developer_key.der` (never expose or commit).
Pace build: `./pacepilot-app/build.sh`.
Gut build: from its folder, monkeyc -d fenix7pro -f monkey.jungle -o bin/guttrain.prg -y <private-key> -w -l 0; add -t and change output for tests.
Run monkeydo serially per app with `fenix7pro -t`, only after simulator is actually available. Inspect PASSED output; a build success is not a test pass.

## Claude's next work: visual design

1. Redesign PacePilot Presenter and Gut Train screens for an at-a-glance round-watch experience: dominant action + HR, timer secondary, minimal helper text, readable bounds away from clipped edges.
2. Use native menus for task lists and keep START/STOP predictable during workouts. Preserve BACK cancellation, finish confirmation, menu accessibility, and native LIGHT behavior.
3. Distinguish near-band, above-band, below-band, missing signal, paused, and DEMO with text/icons as well as color. Preserve slow restrained animation; offer an option to disable it. Avoid equating green with medically safe or low HR with a requirement to exercise harder.
4. Make setup shorter without hiding HR-band review or public-sharing consent. Consider a summary/review page with editable menu items instead of a long sequence, but retain deliberate confirmation.
5. Make the dashboard visually coherent with both apps; clearly label last-upload time and whether a session is finished. Don't label polling as live sensor streaming.
6. Validate each control path, actual menu rendering, app-switch installed/missing/cancel behavior, cooldown/haptics, sensor loss, pause/resume, finish, opt-in sync failure/retry, and offline history. User has not allowed screenshots; ask only if visual capture becomes necessary, otherwise provide a human test checklist.
7. Consider a persistent session draft before app switching in a future iteration. Current implementation blocks switching until completion; it does not migrate active state between apps.

## Official Garmin references used

- Input and behavior delegates: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/BehaviorDelegate.html
- Menu2 delegate: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2InputDelegate.html
- Workflows/button conventions: https://developer.garmin.com/connect-iq/user-experience-guidelines/designing-workflows-and-interactions/
- Backlight/haptics: https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html
- Intents and app switching: https://developer.garmin.com/connect-iq/api-docs/Toybox/System/Intent.html
- exitTo is asynchronous and provides Garmin's own confirmation; cancellation keeps current app running: https://developer.garmin.com/connect-iq/api-docs/Toybox/System.html#exitTo-instance_function

## Completion discipline

Run checks, rebuild release binaries, refresh hashes, sync only changed project folders to checkout, review git diff, commit and push dashboard-and-recovery. A handoff exists proactively because account usage lookup failed; no claim is made that credits are expiring. Do not deploy watch code as though that installs it on a physical Garmin.
