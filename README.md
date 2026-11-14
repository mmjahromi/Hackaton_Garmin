# PacePilot + Gut Train

Two Garmin Fenix 7 Pro watch apps and a shared dashboard for manageable activity and long-session fueling.

**Start with [Current status](STATUS.md)** for implemented features, verification evidence, privacy boundaries, and remaining gaps. It includes the weekly integration on `dashboard-and-recovery`, verified 14 November 2026.

- **PacePilot:** run/walk coaching, HR guidance, animated avatar, local history, check-ins, confirmed next goal, in-workout food/drink logging and cues, optional dashboard plan and sharing.
- **Gut Train:** local daily activity home, configurable food portions and drink cues, timed fueling logs, gut-comfort feedback, confirmed next target, optional sharing.
- **Dashboard:** Today, Workouts, and Fuelling sessions; daily suggestions with explicit decisions, preferences, consistency, meal log, optional energy estimate, live workout updates, and completed summaries.

PacePilot now includes the RaceForge weekly summit adventure: open **Weekly adventure** from its home menu for missions, checkpoints, explicit adjustments, and local saved progress. Missions use the existing PacePilot workout, recovery feedback, fueling, and opt-in dashboard sharing. The weekly trail itself remains local. The [standalone RaceForge app](prototypes/raceforge-avatar/README.md) remains an optional development/demo app.

This prototype has not established health, performance, recovery, or long-term habit outcomes with users. Physical-watch acceptance remains outstanding.

## Run and develop

| Component | Setup, controls, and commands |
| --- | --- |
| PacePilot | [pacepilot-app/README.md](pacepilot-app/README.md) |
| Gut Train | [gut-train-app/README.md](gut-train-app/README.md) |
| Dashboard and APIs | [gut-train-web/README.md](gut-train-web/README.md) |
| RaceForge weekly adventure + avatar lab | [prototypes/raceforge-avatar/README.md](prototypes/raceforge-avatar/README.md) |

Watch target: Connect IQ SDK **9.1.0**, `fenix7pro`, device API profile 5.2. Use Garmin's official Monkey C extension. From the repository root:

```sh
./run-watch.sh pacepilot-app
./run-watch.sh gut-train-app
# Build and execute either app's simulator tests:
./run-watch.sh pacepilot-app test
./run-watch.sh gut-train-app test
```

The launcher restarts the Connect IQ simulator; finish other simulator work first. Root VS Code launch configurations use the same script. Each watch app's `release/` contains production/test PRGs and checksums. Building into `bin/` does not refresh `release/`, deploy the website, or install an app on a physical watch.

For the dashboard, use Node.js 22+ and npm in `gut-train-web/`:

```sh
npm ci
npm test
npm run dev
```

## Connection and sharing

Gut Train makes an app-name-only dashboard request when opened. PacePilot first shows an opening screen; START activates it and makes that request. No request is sent before that START. PacePilot can display a plan offered by the dashboard, with a labeled demo fallback when no real plan is available. Real plan availability requires the dashboard's **Send plan to watch** preference; accepting an offer affects this session's duration only. There is no plan push or nutrition-plan import.

Workout **Share live + summary** defaults off. PacePilot's short review uses UP/DOWN to toggle it before START. With sharing enabled, LIVE workout updates and summaries travel through the paired phone. Watch DEMO workouts do not upload. Daily/background activity uploads remain disabled. See [STATUS.md](STATUS.md#connection-plan-transfer-and-privacy) for exact behavior and limits.

The configured site, [gut-train-web.vercel.app](https://gut-train-web.vercel.app), is a public shared hackathon demo with no user accounts or private reads. Keep session sharing off for private workouts; the app-name check-in still occurs on opening. Signing keys, credentials, and environment files must remain private.

## Evidence and documentation

Latest recorded results: 80 PacePilot simulator tests, 35 Gut Train simulator tests, and 83 dashboard tests; the separate Redis test has earlier recorded passing evidence. PacePilot's80 tests were freshly executed for weekly integration; the Gut Train/dashboard counts remain previously recorded evidence. The new PacePilot weekly log matches the current suite; older debug logs are historical. [STATUS.md](STATUS.md#verification-evidence) distinguishes reports, logs, source inventory, release checksums, and unverified hardware behavior.

[CLAUDE_HANDOFF.md](CLAUDE_HANDOFF.md), [DEBUG_REPORT.md](DEBUG_REPORT.md), and the prep-guide PDF are historical. Use current app READMEs for controls. Supporting folders `breathe-app/` and `starter-app/` remain earlier examples; `time-display-game/` is unrelated.

## Final submission and deployment

See [FINAL_SUBMISSION.md](FINAL_SUBMISSION.md) for the pitch, live link and scope. Deploy the dashboard with `sh deploy-dashboard.sh` from this repository root.
