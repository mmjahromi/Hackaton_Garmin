# PacePilot + Gut Train dashboard

One dashboard for two separate Garmin watch apps. PacePilot supports manageable run/walk sessions and recovery check-ins; Gut Train supports following a chosen fueling plan and reflecting on gut comfort. The overview shows live session totals, a confirmed next goal, check-ins, and fueling/tolerance history. Recovery and Nutrition tabs expose each app’s details. Demo rows are labeled and excluded from live overview totals.

## Run in VS Code

Open this folder in VS Code. With Node.js 22+ and npm installed, run:

```sh
npm ci
npm test
npm run dev
```

Open http://localhost:3000. For a production check, run `npm run build` and `npm start`. The 53 automated tests cover existing rules/APIs, the new PacePilot endpoint, retry deduplication, demo isolation, retention, validation, and nutrition logs. Local production HTTP smoke tests also verify both apps’ active, paused, and completed telemetry. No screenshots or visual checks were performed for this revision.

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
