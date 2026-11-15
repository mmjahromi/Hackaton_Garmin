# Current status: PacePilot + Gut Train

Updated 14 November 2026, including the PacePilot weekly integration after merging RaceForge commits `81599e2` and `648996f` into the implementation at `c5fa03b` on `dashboard-and-recovery`. This is the main reference for current features, verification evidence, and remaining gaps. App READMEs describe setup and controls. Older handoffs, milestone reports, and the prep-guide PDF describe earlier revisions.

## Product and implementation

Two separately installed Garmin Fenix 7 Pro apps share one Next.js dashboard. The current goal is to help the user stay active through manageable sessions, explicit choices, and feedback, with a separate long-session fueling flow. Benefits to health, performance, recovery, or long-term habits have not been measured with users.

Build target: Connect IQ SDK **9.1.0**, `fenix7pro`, round 260 × 260 display, device API profile 5.2. PacePilot's manifest minimum is 3.2.0; Gut Train's is 5.2.0. Dashboard dependencies are declared in [package.json](gut-train-web/package.json): Next.js 16.4.6 and React 19, plain JavaScript and CSS.

| Component | Implemented | Main source |
| --- | --- | --- |
| PacePilot | Run/walk suggestions, configurable HR band, unpaused session goal, energy/soreness/effort check-ins, confirmed next goal, optional routine, local history, animated avatar, opening screen, workout food/drink logging and cues, plan fetch, opt-in sharing | [App and lifecycle](pacepilot-app/source/PacePilotApp.mc), [coaching](pacepilot-app/source/CoachEngine.mc), [features](pacepilot-app/source/Features.mc), [presentation](pacepilot-app/source/Presenter.mc) |
| Gut Train | Local daily activity home, configurable fueling session, food/drink/discomfort logs, sensor context, pause/resume, gut rating, confirmed next target, local summaries, opt-in sharing | [Session](gut-train-app/source/SessionView.mc), [setup](gut-train-app/source/NutritionSetup.mc), [daily activity](gut-train-app/source/ActiveData.mc) |
| Dashboard | Today, Workouts, Fuelling sessions; preferences, daily suggestions and decisions, consistency history, meals, optional energy estimate, live workout chart, check-ins and completed summaries | [Tabs](gut-train-web/app/SharedDashboard.js), [Today](gut-train-web/app/Home.js), [live panel](gut-train-web/app/LiveActivity.js), [nutrition](gut-train-web/app/Dashboard.js) |
| Storage and transport | On-watch storage; Garmin Communications through the paired phone; Redis REST storage or process-memory fallback on the web | [Store](gut-train-web/lib/store.js), [PacePilot sync](pacepilot-app/source/DashboardSync.mc), [Gut Train sync](gut-train-app/source/SummaryView.mc) |
| Avatar | Presentation components integrated into PacePilot; standalone synthetic replay remains independently buildable | [PacePilot bridge](pacepilot-app/source/AvatarBridge.mc), [prototype](prototypes/raceforge-avatar/README.md) |

## PacePilot behavior

- Default goal: 20 unpaused minutes. Walking counts; estimated moving time and unknown-motion time are tracked separately. Settings allow 1–60 minutes.
- Default example HR band: 120–140 bpm; the review shows the chosen band before starting. The app uses filtered, fresh HR and reacquires evidence after loss or resume.
- Above the selected upper bound for 15 seconds suggests **Ease off**; 60 seconds suggests **Walk break**. After at least 60 seconds walking and 30 seconds at or below the recovery threshold (upper bound minus 5), it can offer running again. The user must accept through the task menu; explicit STILL movement blocks the offer.
- HR feedback uses text and band colors, with slow pulsing farther outside the band. A sustained low-band cue asks the user to check effort; it does not automatically increase intensity. Transition vibrations have a real-time cooldown.
- Wrist HR, qualified GNSS speed, accelerometer movement evidence, and pressure trend feed the feature pipeline. Pressure adds context rather than changing HR timing. Missing/stale/unsupported/error states remain explicit.
- The avatar follows the existing coaching output and lifecycle; it does not make coaching decisions. Its separate 250 ms redraw timer stops when covered, hidden, paused, complete, or on the metrics page.
- The opening screen shows the app icon and START to open. Only START activates it and triggers the dashboard request; BACK exits, UP/DOWN and MENU do nothing, and no request is sent before activation. Home → review → workout then takes two START presses after any plan screen is dismissed. UP/DOWN on the short review toggles live sharing. During a workout START pauses/resumes; menus and finish questions leave the workout running until an action is confirmed. LIGHT stays native.
- The workout menu logs 150 ml drinks and 25 g carb portions without pausing. The home Drink reminders choice cycles Auto, Off, 10, 15, or 20 minutes; Auto cues every 15 minutes only for goals of at least 45 minutes. The due cue occupies the small top line and attempts one vibration through the alert gate; logging a drink clears it and resets the interval. Totals appear in metrics, live packets, and shared completed summaries. They are added after the local save and are not retained by the local-history schema. Reminder mode is in memory for this app launch.
- Completed LIVE summaries are retained locally, newest 20. Feedback chooses effort, next goal, and optional routine. FIT activity recording remains disabled in PacePilot.

## Gut Train behavior

- Setup chooses 30–90 g/h in 5 g/h steps, food category (gel, chews, drink, food), 5–60 g per portion, drink cues off/10/15/20 minutes, and default-off sharing. Feed timing uses the chosen target and portion.
- During a workout START pauses/resumes. Hold UP opens food, drink (150 ml), discomfort, resume, and finish tasks. UP/DOWN alone do nothing. Menus and finish questions leave the clock, sensors, recording, cues, and telemetry running; only explicit pause stops workout time.
- HR, movement/GPS, climb, cadence, stops, and wrist temperature provide context. High HR retains the feeding cue. Temperature is recorded when available; it no longer changes drink timing.
- Sessions shorter than 10 unpaused minutes skip rating and nutrition summary storage and discard the FIT recording. If live sharing was enabled, telemetry may already have been sent, including completion.
- Longer sessions ask for gut comfort (1–5), then a user-confirmed next target. The old `Plan.nextTarget()` rule remains in source/tests but is not used to select the next target in this flow. The confirmation starts from the session's target; no automatic increase is applied.
- Stores up to 20 LIVE nutrition summaries and the first 32 timed food entries per session. There is no on-watch nutrition-history browser or sharing retry screen.
- Gut Train attempts a FIT cycling activity with a carbs field, saving qualifying LIVE sessions and discarding DEMO/short recordings. Real-watch recording, pause/resume, and Garmin Connect delivery remain unverified.
- Local daily activity rules remain: weekly target starts at 150, increases 10% after success (cap 300), decreases 10% below 80% completion (floor 60), with nearest-five rounding. Today's remaining share has a 10-minute floor; morning Body Battery below 30 multiplies it by 0.6. Background checks run every 30 minutes; a 200-step response within that interval is an approximate nudge response. Daily and demo-day uploads are disabled by `ActiveSync.post()`.

## Dashboard plans, meals, and demo

- **Today** shows preferences, a daily suggestion and reason, explicit decisions (accept, adjust, reschedule, easier, rest), watch-data status, consistency, meals, completed-workout food/drink totals from both apps, and optional energy estimates. **Workouts** shows the live panel and completed summaries/check-ins. **Fuelling sessions** exposes nutrition history and the earlier analysis/goal controls.
- The only profile goal is `stay_active`. Preferences support walk, run/walk, or cycle, selected days, usual duration, and experience. Dashboard duration choices span 10–90 minutes.
- Daily suggestions repeat the usual duration by default. Three recent manageable sessions can offer 10% more, rounded to five minutes, capped at usual + 15 and 90. Recent too-hard feedback, high soreness, low energy, or a recovery-day record offers 25% less (minimum 10) and changes run/walk to walking. Two missed planned days offer a 60% restart (minimum 10) without catch-up. Unplanned days suggest rest with an optional 10-minute walk. HR does not drive these changes; decisions remain explicit.
- Missed-day adaptation starts from the saved profile's enrollment date. The consistency display uses a 14-day window. Existing legacy day records can still be read, but current watches do not upload new daily records.
- Meals are manually entered calories on the dashboard. The optional adult energy estimate uses Mifflin–St Jeor × a typical-day factor (1.2, 1.375, or 1.55), with an approximate ±10% display range. It requires all inputs; it is not a measured expenditure or confidence interval. Logged intake and reported activity calories stay separate from that estimate.
- Today demo data is deterministic and relative to today. Demo profile/decisions/meals have separate storage; reset clears only those demo changes. Real mode does not use generated demo history. Watch DEMO workouts suppress live and summary uploads and preserve LIVE storage.

## Connection, plan transfer, and privacy

1. Gut Train requests `/api/watch-config?app=...` on opening; PacePilot does so only after START on its opening screen; the server records an app-name check-in. This happens independently of session-sharing consent and contains no workout/health payload. It proves the app reached the server, not continuous pairing or a live sensor stream. PacePilot sends no check-in before activation.
2. PacePilot displays a real suggestion when dashboard **Send plan to watch** consent is on. A successful response without an available real plan triggers a clearly labeled demo-plan request. START accepts a usable offer for this session; BACK keeps the watch goal. Accepting a demo plan does not change workout mode: LIVE/DEMO selection separately controls sensors and sharing. Demo plan IDs are not reported as real plan completions.
3. Plan transfer is on request, not push. PacePilot imports a duration, capped at 60 minutes even if the dashboard offers up to 90; the activity label does not create a separate cycling coaching engine. Gut Train's startup request is a connection check, not a nutrition-plan import. Legacy dashboard race/fueling goal controls do not configure either watch.
4. Session **Share live + summary** is separately opt-in and defaults off. PacePilot's short review now exposes the switch; it resets after each session. Communication goes through the paired phone, not Garmin Health cloud APIs. Offline coaching/local storage work without dashboard access.
5. With consent in LIVE mode, each app attempts a normal snapshot at most every five seconds, with lifecycle-change attempts and one request in flight. Snapshots include HR/activity metrics and optional Garmin stress history with its timestamp. Stress reads are attempted at most once a real minute; availability is not guaranteed and readings older than five minutes are labeled as old. No raw GPS coordinates are uploaded.
6. Today refreshes its overview every three seconds, completed summary lists every five, and the Workouts live panel every two. The live panel uses a one-second age display and marks active/paused streams stale after 20 seconds without a fresh received/sample timestamp; missing HR and long gaps remain chart gaps. Paused/completed packets suppress current HR/stress. End delivery is best effort; lost connectivity can leave a stale stream.
7. Live storage holds the newest session per app/mode, up to four shared channels, with 120 snapshots per channel and a 24-hour visibility window. Redis uses atomic ordering checks to reject duplicate/delayed packets and reopening of a completed session. Completed summaries are separate: newest 200 per app. PacePilot packets now include logged carbs/fluids as well as its activity metrics. PacePilot summary retries upsert by mode/session ID; Gut Train summaries append and are not deduplicated that way.
8. The configured dashboard address is [gut-train-web.vercel.app](https://gut-train-web.vercel.app). Deployment and simulator-to-server results below are prior records, not a fresh production inspection. The shared site has no user accounts, private reads, or device enrollment. Optional `INGEST_KEY` gates selected watch-write routes only; supplied watches do not send it. Profile/meal/plan routes, legacy goal writes, and app-name check-ins are not protected by that key. This is shared demo storage, not private or multi-user health tracking.

## Weekly adventure integrated into PacePilot

PacePilot now offers **Weekly adventure** from its home menu. It embeds RaceForge's pure plan, journey, storage and summit components, with a PacePilot-specific navigation/result adapter (`pacepilot-app/source/Weekly.mc`). Selecting a mission opens the existing workout review; the existing controller, sensors, recovery feedback, fuel logging and optional dashboard sharing handle the session. No separate workout controller or second app is needed.

Initial setup selects baseline, available days, preferred activity and time. The trail offers mission previews, relative plan days1–7, checkpoints and a final explicit summit check-in. MENU offers confirmed missed/shorten/move/skip proposals; earned achievements remain. Walking/recovery missions suppress running offers and mobility uses a resting avatar. Timed completion is not proof of active movement or correct technique.

Progress advances only after post-workout feedback is confirmed. Partial results do not award a checkpoint. Failed saves roll back progress and remain retryable from the summary. Eight results and twelve changes are bounded in versioned `pacepilot.weekly.v1` local storage; corrupt/unknown records remain read-only. DEMO has a separate temporary journey and cannot modify LIVE progress. Startup activation, live-sharing consent, summary retry, normal workouts and dashboard-plan fetch remain. Abandoning a dashboard plan clears its provenance so unrelated workouts cannot mark it completed.

Remaining boundaries: the weekly trail itself is local; dashboard live/session sharing remains the existing workout feed. No migration from the separate RaceForge app's private storage, automatic calendar rollover, in-progress workout restoration or new physical-watch/visual acceptance is provided. Existing standalone adventure and pose lab remain buildable for development.

## Historical RaceForge branch merge

The `feature/raceforge-avatar` additions are merged into `dashboard-and-recovery`. The original avatar remains integrated into PacePilot. At the merge, the newer weekly adventure was an independently launched app under `prototypes/raceforge-avatar/`, not a new dashboard tab or a replacement for PacePilot's workout UI.

It adds baseline/preferences setup, mountain checkpoints, weekly missions, previews, explicit completion, partial results, missed/shorten/move/skip proposals, fatigue/fueling/effort check-ins, and bounded versioned local journey persistence. DEMO progress remains temporary; LIVE progress is saved. It imports the existing PacePilot controller/providers/feature pipeline/coaching engine through explicit source paths, rather than duplicating their rules. The avatar pose lab remains available through its summit menu.

The branch records 21 simulator tests passing. At that point embedding was outstanding. PacePilot embedding is now implemented as described above; web trail sync and physical-watch acceptance remain outstanding. See the [RaceForge guide](prototypes/raceforge-avatar/README.md) and [milestone 3 report](prototypes/raceforge-avatar/MILESTONE3.md) for controls, storage limits, and prior evidence. Fresh checks after merge commit `8e6c7c1` on 14 November 2026:

- RaceForge production and test builds succeeded with SDK 9.1.0. Its simulator suite passed **21/21**, with no failures or errors; log: `prototypes/raceforge-avatar/bin/simulator-tests.log` (ignored build output).
- PacePilot production and test builds succeeded against the merged checkout. Its 68-test runtime suite was not rerun for this merge.
- The merge changes no source in `pacepilot-app/`, `gut-train-app/`, or `gut-train-web/` relative to `c5fa03b`; the existing implementations are preserved. RaceForge's new code imports their existing shared modules.
- Documentation overlap was resolved; no unmerged paths or whitespace errors remain. Documentation edits were preserved for the later integration commit. No web tests, screenshots, physical-device checks, deployment, or push were performed for this merge.

The two inherited RaceForge build warnings remain: language declarations and scaling its 24 px launcher icon to 40 px.

## Current integration verification

On 14 November 2026, both PacePilot production and test builds succeeded with SDK9.1.0 / fenix7pro. The full simulator suite passed **80/80**, zero failures/errors, including twelve mission integration regressions alongside the prior68 tests. Raw evidence: [weekly-simulator-results.txt](pacepilot-app/tests/weekly-simulator-results.txt). The entry regression was observed failing before implementation; the abandoned-dashboard-plan regression was also observed failing before correction.

Release production/test PRGs and their SHA-256 fingerprints were refreshed after this passing run. The standalone RaceForge suite was also rerun successfully: **21/21** after integration. Source review found and corrected setup bypass and abandoned-plan attribution. No screenshots, visual acceptance, real-watch/phone tests, web deployment or production data writes were performed. Web code is unchanged; its tests were not rerun because npm is unavailable here.

## Earlier verification evidence

The rows below preserve earlier results; the current PacePilot integration results are recorded above. Source review and checksum verification do not establish runtime behavior or physical acceptance.

| Area | Latest recorded evidence | Evidence limit |
| --- | --- | --- |
| PacePilot | Commit `c5fa03b` records 68 simulator tests passing and no check-in before START; source contains 68 test functions. Earlier `1ca150b` records a LIVE simulator workout reaching the dashboard with 13 updates then completion | Saved raw debug log is older (36 passes); no current hardware session |
| Gut Train | README and commit `c6742fd` revision record 35 simulator tests and startup check-in reaching the live dashboard; source contains 35 test functions | Saved raw debug log is older (28 passes); not a physical watch test |
| Dashboard | Commit `c5fa03b` records 83 tests passing; preceding stay-active revision records production build/deployment | Earlier counts were 82, 81, and 54; no fresh production inspection, build, or suite run here |
| Redis live storage | Debugging revision records 1 isolated Redis integration test passing, including ordering, completion protection, channel isolation, retention, TTL | Separate optional test; not included in the 83 standard tests |
| Watch releases | Production and test PRGs exist for both apps; all four SHA-256 values match their release manifests in this documentation review | Matching hashes do not prove binaries correspond to every later source edit or that a physical watch has them installed |
| RaceForge adventure / avatar | Fresh post-merge build and 21/21 simulator tests pass; includes the original nine avatar regressions | Does not validate integrated PacePilot screens, physical sensors, or hardware smoothness |

During the earlier documentation-only pass, no application tests/builds were rerun; the later integration pass executed the fresh checks above. The attempted web test run could not start because `npm` is unavailable, and `gut-train-web/node_modules` is absent. No screenshots or new screen capture were taken. No application code or binaries were changed.

## Remaining gaps and acceptance

| Gap | Current boundary / next verification |
| --- | --- |
| Physical Garmin + phone acceptance | Install both PRGs on Fenix 7 Pro; exercise real sensors, connectivity, offline behavior, local persistence, permissions, teardown, haptics, app switching, and sharing failure/retry |
| Screen and native control acceptance | Inspect all integrated screens by eye; press every menu/confirmation/cancel path; confirm circle clearance, opening-screen icon, drink-cue placement, missing-HR wording, readability, and avatar smoothness/memory. Automated tests and the standalone recording do not establish these |
| Visual redesign | Integrated avatar and functional screens exist; requested full watch/dashboard polish remains pending. Earlier handoff reserves visual redesign for Claude |
| FIT lifecycle | PacePilot recording disabled; Gut Train attempts recording but save/discard/pause/resume and Garmin Connect results need real-device acceptance |
| Watch plan transfer | Test real-phone request and acceptance, consent-off/demo fallback/offline cases, and 60-vs-90-minute duration limits; no automatic push or nutrition plan import |
| Periodic idle heartbeat | Startup app-name check-ins work per recorded simulator evidence; `/api/heartbeat` exists, but no periodic idle watch sender is implemented |
| Watch-side everyday meals | Dashboard calorie log and PacePilot fixed-portion workout logs exist; everyday meal/calorie-entry UI on the watch is not built |
| Celebration and shorter sessions | The weekly summit includes the celebration avatar; ordinary workout completion remains text/feedback. Gut Train still discards sub-10-minute nutrition sessions rather than offering a separate short-workout flow |
| Sharing resilience | No durable offline upload queue. PacePilot provides summary retry; Gut Train does not. Completion delivery is best effort; Gut Train summary retries lack idempotent session identity |
| Private/multi-user use | Add accounts, authenticated enrollment/reads/writes and per-user/device storage before treating this as private tracking; current app/mode channels and profile are shared |
| Device performance and outcomes | Real MIP rendering, memory, battery use, sensor accuracy/availability, and user benefits remain unmeasured |
| Fresh verification evidence | Rerun current suites/builds in an equipped environment and preserve matching logs; the new PacePilot weekly log matches the current suite; older watch debug logs and Gut Train evidence remain historical |

## Documentation and supporting projects

- [Repository guide](README.md); [PacePilot setup/controls](pacepilot-app/README.md); [Gut Train setup/controls](gut-train-app/README.md); [dashboard/API guide](gut-train-web/README.md).
- [PacePilot demo](pacepilot-app/DEMO.md); [verification history and hardware checklist](pacepilot-app/TEST_RESULTS.md); [local activity implementation notes](gut-train-app/docs/stay-active.md).
- [Claude handoff](CLAUDE_HANDOFF.md) and [debugging report](DEBUG_REPORT.md) are historical records. The [11-page prep guide](Hack%20West%202026%20prep%20guide.pdf) and external [Claude pitch deck](https://claude.ai/artifact/Q13Haahwz2TBcyCRgxi1zG) / [prep guide](https://claude.ai/artifact/1ZPKdKz8HwN5Vtg1oXh9fs) predate the two-app implementation; their old buttons, automatic target progression, uploads, and counts are not current instructions.
- `breathe-app/` is the earlier stress/breathing fallback; `starter-app/` is the toolchain tap-counter example. `prototypes/raceforge-avatar/` now includes the standalone weekly adventure as well as its avatar lab. `time-display-game/` is unrelated and outside this work.
- `run-watch.sh` and root `.vscode/launch.json` launch either main watch app. Release PRGs and checksums live in each app's `release/`. Signing keys remain private and outside shared artifacts.
