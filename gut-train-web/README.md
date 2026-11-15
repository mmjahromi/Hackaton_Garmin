# PacePilot + Gut Train dashboard

One dashboard for two separate Garmin watch apps. PacePilot supports manageable run/walk sessions and recovery check-ins; Gut Train supports following a chosen fueling plan and reflecting on gut comfort. The overview shows live session totals, a confirmed next goal, check-ins, and fueling/tolerance history. Recovery and Nutrition tabs expose each app’s details. Demo rows are labeled and excluded from live overview totals.

## Run in VS Code

Open this folder in VS Code. With Node.js 22+ and npm installed, run:

```sh
npm ci
npm test
npm run dev
```

Open http://localhost:3000. For a production check, run `npm run build` and `npm start`. The 54 automated tests cover existing rules/APIs, the new PacePilot endpoint, retry deduplication, demo isolation, retention, validation, and nutrition logs. Local production HTTP smoke tests also verify both apps’ active, paused, and completed telemetry. No screenshots or visual checks were performed for this revision.

## Data and integration

- `GET/POST /api/pace-sessions`: PacePilot schema-v1 summaries, plus optional energy, soreness, effort, routine, and nextGoalSec. Missing feedback remains unknown. Retries replace the same mode/session ID. Retains 200 records.
- `GET/POST /api/sessions`: Gut Train summaries, plus foodType, portionG, drinkIntervalS, bounded fuelLog (32 entries), and targetConfirmed. Retains 200 records.
- Legacy `/api/days` and `/api/goal` remain compatible. This watch revision keeps daily activity local rather than automatically uploading it.
- Each watch app asks separately whether to share its session; both default off. They send via the paired phone using Garmin Communications. No Garmin Health cloud API is used.
- The apps are separate installations. The dashboard combines their summaries; it does not launch apps on the watch, link accounts, infer causal relationships, or push goals back to either app.

Optional Redis environment variables: `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` (or `KV_REST_API_URL` and `KV_REST_API_TOKEN`). Without Redis, data stays in process memory and disappears on restart. Never commit credentials.

The live prototype is a shared, unauthenticated hackathon dashboard at https://gut-train-web.vercel.app. Uploaded summaries are public. `INGEST_KEY` can restrict writes, but the supplied watch builds do not include a key and will show a sharing failure if it is required. Authentication, per-user isolation, private reads, and secure device enrollment are required before a personal-data launch. Existing prototype goal controls do not configure watch targets.

Deploy to the existing Vercel project with `npx vercel deploy --prod --yes` when authorized and signed in.

## Live workout feed (current revision)

Enable **Share live + summary** during watch setup, then start a LIVE session with the paired phone connected to the Internet. This explicitly shares heart rate and workout metrics to the public demo. It defaults off. DEMO sessions remain local in the watch builds; API tests use labeled synthetic packets only against isolated/local storage.

Each watch uploads at most one normal snapshot every 5 seconds, with immediate status-change attempts and a single request in flight. The dashboard live panel polls every 2 seconds. This is near-live HTTP telemetry via Garmin Communications, not a guaranteed low-latency socket. Slow Bluetooth/phone/network connections can delay updates. No raw GPS coordinates are uploaded.

PacePilot sends filtered HR when ready, elapsed time, goal, estimated moving time, speed, and active/paused/completed state. Gut Train sends HR, elapsed time, distance, speed, logged carbs/fluids, and state. Paused/completed packets carry no current HR. The dashboard shows the last120 snapshots (about 10 min at the nominal rate); gaps are not interpolated. After 20 sec without a fresh sample it marks the stream stale and stops presenting old HR as current. End delivery is best effort: if connectivity is lost while ending, the dashboard becomes stale rather than inventing completion.

The API keeps the newest session per app/mode for up to 24 h, with atomic Redis ordering checks to ignore duplicate, delayed, or post-completion packets. This is a shared hackathon feed, not multi-user private tracking. Existing summaries remain separate. The new watch binaries must be installed; deploying the website does not update the watch.

## Redis integration check

With local `redis-server` and `redis-cli` installed, run `npm run test:redis`. This starts a temporary password-protected Redis bound to loopback, executes the production Lua storage code, and shuts it down. It verifies concurrent/out-of-order packets, completion protection, separate channels, bounded history, and expiry configuration without touching production data. Latest result: 1/1 integration test passes, in addition to 54/54 standard tests.

## Stay-active revision

The first tab, **Today**, answers four questions in order: what is my goal, what is suggested today and why, is my watch sending data, and how consistent have I been. A fifth section logs meals and shows an optional energy estimate.

| Endpoint | Purpose |
| --- | --- |
| `GET /api/overview[?mode=demo&today=YYYY-MM-DD]` | Everything the Today tab shows, in one request |
| `GET` / `PUT /api/profile` | Goal (only `stay_active`), activities, days, usual minutes, experience, optional health details, "Send plan to watch" consent |
| `GET /api/plan`, `POST /api/plan/decision` | Today's suggestion with its reason; accept, adjust, reschedule, easier, rest |
| `GET /api/watch-config` | The plan summary PacePilot fetches on request; `available:false` without consent |
| `GET` / `POST /api/heartbeat` | Idle check-in from a watch app (endpoint only; no watch sends it yet) |
| `GET` / `POST` / `DELETE /api/meals` | User-entered calories |
| `POST /api/demo/reset` | Clears changes made while exploring the demo |

**Plan rules** (`lib/plan.js`): repeat the usual length by default; after three sessions rated easy or about right with no high soreness or low energy, offer 10% more (rounded to 5 minutes, at most usual + 15, never above 90); after a too-hard session, high soreness or low energy, offer 25% less and swap run/walk for a walk; after two missed planned days in a row, offer a restart at 60% with no catch-up; on unplanned days suggest rest with an optional 10-minute walk. Heart rate never changes a suggestion, nothing applies without a decision, and days before the preferences were first saved are never counted as missed.

**Energy estimate** (`lib/energy.js`): Mifflin-St Jeor resting estimate times an activity factor for a typical day (1.2, 1.375 or 1.55), shown as a range of about 10% either way. Shown only when age (18+), height, weight, sex for the formula and typical day are all given. Garmin's activity calories and entered intake are separate figures and are never added to the estimate.

**Demo data** (`lib/demo.js`): a two-week history generated relative to today with no randomness: nine sessions (one too hard with sore legs, one at a faster pace, one with no heart-rate reading), two missed planned days and five meals. Seven of the sessions carry an average heart rate and speed at about the same walking pace, so the fitness trend has something to compare. It is served from the generator under `?mode=demo`, marked `demo: true`, stored under `gut-train:demo:*` keys, and never read in real mode. Real mode with no data shows empty states.

**Fitness trend** (`lib/efficiency.js`): heartbeats per km, worked out as average heart rate divided by speed over the seconds the watch had both a heart rate and a moving GPS speed. Lower means the heart works less for the same pace. Only sessions within 15% of the person's usual (median) pace and with at least 5 minutes of usable readings are compared; the rest are counted and named as left out. It needs at least four comparable sessions, compares the earlier half with the recent half, and calls a change of less than 3% "steady". Age, height and weight are not used. Heat, hills, sleep and caffeine all move heart rate, and the page says so.

**Connection states**: waiting for watch data, receiving live activity, workout paused, connection stale or interrupted (no update for 20 seconds), workout completed. These describe data reaching the dashboard; the page says plainly that it cannot tell whether a watch is paired.

Tests: `npm test` runs 89 (fitness trend, plan rules, estimate arithmetic, validation, consent gate, demo isolation, plus the earlier live-feed and insight tests).
