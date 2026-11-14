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

- Dashboard: **44 automated tests pass**, production build passes, and local HTTP checks return 200 for the page and both session endpoints.
- Both watch production and test builds compile.
- Revised watch suites contain 31 PacePilot and 24 Gut Train tests. Runtime execution is **not verified** for this revision because the host simulator failed to launch. Earlier passing test logs apply to the older baseline.
- No physical-watch or visual acceptance has been performed. No screenshots were taken.

Ready-to-sideload builds are in each watch app’s `release/` directory. Keep signing keys and credentials outside git. Before a device demo, verify the new setup/feedback screens, sensor input, offline storage, and opt-in sync on the actual watch.
