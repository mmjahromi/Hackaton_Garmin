# PacePilot + Gut Train

Two focused Garmin Fenix 7 Pro watch apps, one shared dashboard.

- **PacePilot:** manageable run/walk coaching, energy and soreness check-ins, session effort feedback, a user-confirmed next goal, and an optional post-run routine.
- **Gut Train:** a configurable fueling plan, timed food/portion logs, drink cues, gut-comfort feedback, and a user-confirmed next fueling target.
- **Shared dashboard:** Overview, Recovery, and Nutrition views combine summaries while keeping each app’s data distinct.

The problem is turning activity and fueling intentions into routines you can follow and reflect on. This prototype supports that loop; it has not demonstrated medical recovery, improved performance, or long-term habit outcomes.

## Run in VS Code

Open the individual folder for the app you want to run:

| Folder | Instructions |
| --- | --- |
| `pacepilot-app` | [SDK setup, VS Code, controls, build, and tests](pacepilot-app/README.md) |
| `gut-train-app` | [Nutrition setup, controls, build, and tests](gut-train-app/README.md) |
| `gut-train-web` | [Node setup, local dashboard, APIs, and deployment](gut-train-web/README.md) |

Watch builds use Connect IQ SDK 9.1.0 and device `fenix7pro`. They call Garmin Connect IQ sensor APIs. Optional summary sharing uses Garmin Communications through the paired phone, rather than Garmin Health cloud APIs. The watch apps are separate installations and work without the dashboard.

Both apps default to keeping session summaries on the watch. Sharing is an explicit per-session choice. The shared hackathon dashboard is public, has no user accounts, and must not be treated as private health-data storage. Daily activity and demo sessions do not upload in this revision. Dashboard edits do not push plans back to either watch app.

## Verification for this revision

- Dashboard: **53 automated tests pass**, production build passes, and local HTTP checks return 200 for the page and both session endpoints.
- Both watch production and test builds compile.
- Current watch suites pass in the simulator: **35 PacePilot tests and 27 Gut Train tests**. Hardware acceptance remains outstanding.
- No physical-watch or visual acceptance has been performed. No screenshots were taken.

Ready-to-sideload builds are in each watch app’s `release/` directory. Keep signing keys and credentials outside git. Before a device demo, verify the new setup/feedback screens, sensor input, offline storage, and opt-in sync on the actual watch.

## Controls and next work

Workout START/STOP controls the timer; hold MENU/UP opens task choices. Native menus still use START to select. LIGHT keeps Garmin’s standard behavior. PacePilot adds text-backed HR band colors and slow pulsing outside the band. App switching uses Garmin intents and requires finishing a workout first. Dashboard polling now follows live workout telemetry as well as completed summaries.

See [Claude handoff](CLAUDE_HANDOFF.md) for the requested visual redesign, exact remaining validation, and implementation boundaries.

## Live workout feed (current revision)

Enable **Share live + summary** during watch setup, then start a LIVE session with the paired phone connected to the Internet. This explicitly shares heart rate and workout metrics to the public demo. It defaults off. DEMO sessions remain local in the watch builds; API tests use labeled synthetic packets only against isolated/local storage.

Each watch uploads at most one normal snapshot every 5 seconds, with immediate status-change attempts and a single request in flight. The dashboard live panel polls every 2 seconds. This is near-live HTTP telemetry via Garmin Communications, not a guaranteed low-latency socket. Slow Bluetooth/phone/network connections can delay updates. No raw GPS coordinates are uploaded.

PacePilot sends filtered HR when ready, elapsed time, goal, estimated moving time, speed, and active/paused/completed state. Gut Train sends HR, elapsed time, distance, speed, logged carbs/fluids, and state. Paused/completed packets carry no current HR. The dashboard shows the last120 snapshots (about 10 min at the nominal rate); gaps are not interpolated. After 20 sec without a fresh sample it marks the stream stale and stops presenting old HR as current. End delivery is best effort: if connectivity is lost while ending, the dashboard becomes stale rather than inventing completion.

The API keeps the newest session per app/mode for up to 24 h, with atomic Redis ordering checks to ignore duplicate, delayed, or post-completion packets. This is a shared hackathon feed, not multi-user private tracking. Existing summaries remain separate. The new watch binaries must be installed; deploying the website does not update the watch.
