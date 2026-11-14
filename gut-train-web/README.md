# PacePilot + Gut Train dashboard

A shared Next.js dashboard for two separately installed Garmin watch apps. Current tabs are **Today**, **Workouts**, and **Fuelling sessions**. [STATUS.md](../STATUS.md) is the main reference for feature scope, verification evidence, privacy, and remaining gaps.

## Run locally

Use Node.js **22+** and npm. Open this directory in VS Code, then:

```sh
npm ci
npm test
npm run dev
```

Open `http://localhost:3000`. For production checks, run `npm run build`, then `npm start`. `npm run test:redis` separately requires local `redis-server` and `redis-cli`; it starts an isolated password-protected loopback Redis, runs the production live-storage Lua checks, and shuts it down without touching production data.

Dependencies are declared in [package.json](package.json): Next.js 16.4.6, React 19, plain JavaScript/CSS. No credentials are needed for process-memory development. Optional Redis variables are `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN`, with `KV_REST_API_URL` / `KV_REST_API_TOKEN` aliases. Without both URL and token, data is kept in process memory and disappears on restart; it is unsuitable for durable serverless storage.

Deploy to the existing Vercel project only when authorized:

```sh
npx vercel deploy --prod --yes
```

The configured public address is [gut-train-web.vercel.app](https://gut-train-web.vercel.app). Prior records report deployment; this documentation update did not inspect or redeploy production. Website deployment does not update installed watch PRGs.

## Current features

- **Today** (`app/Home.js`): preferences, suggestion and reason, explicit plan decisions, watch-data states/check-ins, two-week consistency, meals, optional energy estimate, completed-workout food/drink totals from both apps, labeled isolated demo. Overview refreshes every three seconds.
- **Workouts** (`app/SharedDashboard.js`, `app/LiveActivity.js`): live workout chart and sensor readings, reported feedback/next goal, and completed session histories. Summary polling is every five seconds; live polling every two.
- **Fuelling sessions** (`app/Dashboard.js`): Gut Train history, sensor context, fixed-rule insights, legacy daily activity display and race/fueling goal controls. The nutrition component polls its endpoints every two seconds. These goal controls do not change watch settings.
- **Plans** (`lib/plan.js`): only `stay_active`; explicit accept/adjust/reschedule/easier/rest decisions. Recent activity and feedback can offer longer, shorter, restart, or rest sessions. HR does not drive progression. [Exact rules](../STATUS.md#dashboard-plans-meals-and-demo) and known duration/import limits are recorded centrally.
- **Meals and energy** (`lib/meals.js`, `lib/energy.js`): manual calorie entries and an optional adult Mifflin–St Jeor estimate × a typical-day activity factor. The ±10% display is approximate, not a confidence interval. Intake and reported activity calories are separate figures, never added to the estimate.
- **Demo** (`lib/demo.js`): deterministic history relative to today; separate demo profile/decisions/meals and reset. Today demo reads no real activity, telemetry, or check-ins. Existing summary APIs can retain labeled demo records, but current watch DEMO workouts suppress uploads.

## API map

| Endpoint | Methods | Purpose and integration |
| --- | --- | --- |
| `/api/overview` | GET | Aggregate Today data; optional `mode=demo` and `today=YYYY-MM-DD` |
| `/api/profile` | GET, PUT | Activity preferences, optional estimate inputs, Send plan to watch consent |
| `/api/plan` | GET | Today's suggestion and consistency |
| `/api/plan/decision` | POST | Accept, adjust, reschedule, easier, rest |
| `/api/watch-config` | GET | On-request plan response; `app=pacepilot` or `app=guttrain` also records an app-name check-in; `mode=demo` returns a labeled demo offer |
| `/api/heartbeat` | GET, POST | Check-in records; no periodic idle watch sender is implemented |
| `/api/meals` | GET, POST, DELETE | User-entered calorie log |
| `/api/demo/reset` | POST | Clear demo profile, decisions, and entered meals only |
| `/api/pace-sessions` | GET, POST | Schema-v1 PacePilot summaries, feedback and optional fluidMl/carbsG totals; upsert by mode/session ID; newest 200 |
| `/api/sessions` | GET, POST | Gut Train summaries, confirmed target and up to 32 timed food entries; append; newest 200 |
| `/api/live` | GET, POST | Validated live packets and bounded per-app/mode history, separate from summaries |
| `/api/days` | GET, POST | Legacy date-upserted activity records; newest 60; current watches do not upload days |
| `/api/goal` | GET, PUT | Legacy event/race/fueling dashboard goal; no watch configuration push |

Current schemas and validation live in route files and `lib/profile.js`, `lib/pace.js`, `lib/live.js`, `lib/meals.js`. Units remain explicit in names: seconds, grams, milliliters, meters, m/s, bpm, and Unix seconds. Optional signed temperatures distinguish missing from real 0 °C. Test discovery is `lib/*.test.mjs`; the Redis integration file is separate.

## Plan transfer and live updates

Gut Train calls watch-config when opened with its app name. PacePilot first shows an opening screen; START activates it and then calls watch-config. Nothing is sent before that START. This records server reachability, not continuous phone pairing. Gut Train uses it for a connection label. PacePilot offers a consent-gated real plan, or explicitly requests a labeled demo offer if a successful response has no real plan. Accepting a demo offer does not select the workout's LIVE/DEMO mode. No demo plan ID is reported as real completion. Accepted duration is capped at 60 minutes in PacePilot; the dashboard permits up to 90. There is no background plan push, nutrition-plan import, or sport-specific coaching switch from an activity label.

LIVE telemetry requires separate session sharing consent, default off. Normal snapshot attempts are at most every five seconds, lifecycle changes can attempt immediately, and each sender allows one request in flight. HR, elapsed time, app-specific workout metrics, and optional timestamped Garmin stress history are shared; raw GPS coordinates are not. Paused/completed packets suppress current HR and stress.

The live panel marks an active/paused stream stale when received or sample age exceeds 20 seconds. HR gaps are preserved. Stress is read by the watch at most once a real minute and labeled old beyond five minutes. An unavailable reading remains unknown. Completion delivery is best effort, so a disconnected watch may leave a stale stream rather than a confirmed end.

`lib/store.js` retains the newest session per app/mode (four shared channels), 120 snapshots per channel, and a 24-hour visibility window. Redis uses atomic Lua compare/update checks for ordering, duplicates, and completed-session protection. Summary storage remains separate. This supports one shared demo stream per app/mode, not multiple identified users.

## Privacy and storage limits

This site is shared and unauthenticated. Uploaded activity, summaries, profile information, and meal data are not private. **Send plan to watch** controls real plan availability; **Share live + summary** controls each watch session's uploads. App-name check-ins happen separately (after START activation in PacePilot). Daily/background watch uploads and watch DEMO workout uploads are disabled.

Optional `INGEST_KEY` requires `x-api-key` on the session, live, day, and heartbeat write routes. It does not authenticate reads, profile/meal/plan decisions, legacy goal writes, demo reset, or watch-config check-ins. The supplied watches send no key, so enabling it breaks their protected uploads. There are no accounts, private reads, secure enrollment, or per-user storage. Never commit credentials or use this prototype as private health-data storage.

Redis retention: 200 summaries per app, 60 days, 60 plan decisions per real/demo namespace, 300 meals per namespace, and newest check-in per app. The real profile and live channels are shared. Local memory fallback follows the same product boundaries but is lost on restart. Meal/decision/profile writes are not an atomic multi-user system.

## Verification and gaps

Commit `c5fa03b` records **83 standard tests passing**; the preceding stay-active revision records a successful production build/deployment. Earlier debugging records report **1 separate Redis integration test** passing. No suites/builds were rerun for this documentation update: `npm` is unavailable and `node_modules` is absent. See [the evidence register](../STATUS.md#verification-evidence), rather than treating old 35/54-test counts as current.

Physical-watch/phone acceptance, current screen/button inspection, private multi-user support, durable watch upload queues, periodic idle heartbeat, and broader watch plan synchronization remain open. The complete [gap list](../STATUS.md#remaining-gaps-and-acceptance) distinguishes unbuilt features from implemented but unverified behavior.
