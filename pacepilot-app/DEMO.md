# PacePilot demonstration

## Prepare

Use the [current controls](README.md#controls) and [status/evidence register](../STATUS.md). Build with SDK 9.1.0 and load PacePilot into the Fenix 7 Pro simulator (from the repository root: `./run-watch.sh pacepilot-app`).

Opening the app shows its icon and START to open. Press START to activate it and try the dashboard plan request; nothing is sent before that press. Dismiss the startup offer with BACK to reach home. Hold UP/MENU → **Change settings**, then use UP/DOWN to select **Replay standard** on the mode screen. Advance through the illustrative HR band, goal, check-ins, goal choice, and sharing; leave sharing off. Final START starts the replay. The home screen's short two-press start uses the already selected mode; it is not the mode selector.

The workout avatar is integrated. Menus and finish questions leave the workout running; START alone pauses/resumes. A labeled demo plan received from the dashboard is separate from DEMO workout mode—choose Replay standard explicitly for synthetic sensor data.

The mode banner reads DEMO 4x. The demo goal is three virtual minutes. The example HR band is 120–140, recovery threshold 135. Four sequential virtual ticks run each real second.

| Virtual second | Observed by unit test |
| --- | --- |
| 36 | Ease off |
| 81 | Walk break |
| 141 | Try running |
| 160 | Scripted acceptance returns to Run easy |
| 180 | Goal met |

Choose Replay HR loss for the separate loss demonstration. HR disappears at seconds 115–129. The app shows HR unavailable, suppresses running readiness, and requires fresh acquisition. The same underlying engine handles both modes.

## Showing the shared dashboard

Open its **Today** tab and select its labeled demo to show preferences, suggestions, consistency, and meals. The watch replay does not upload; do not promise that its synthetic workout appears in Workouts. The latest commit records a separate simulator LIVE-sharing demonstration. To repeat it, explicitly choose LIVE, enable sharing on the short review with UP/DOWN, and keep the phone/simulator network path online. Only use data you intend to put on the public demo.

Simulator execution and earlier standalone avatar recordings do not verify integrated screen readability or physical Garmin sensors. No new screenshots were taken for this documentation update.

## Three-minute pitch

**0–25 seconds.** “An easy run gets harder when the road climbs. The number on your wrist may rise, but deciding what to do next can still feel unclear. PacePilot gives one next step and treats walking as part of completing the session.”

**25–45 seconds.** “This offline Fenix 7 Pro app uses sustained heart rate to suggest easing off or walking. Movement evidence and pressure trends add context. You choose the HR band and remain in control.”

**45–65 seconds.** State the verified deployment result. Current evidence supports: “The software builds for Fenix 7 Pro, and its unit tests run in that simulator. Physical sensor acquisition and on-watch deployment are still unverified.” If the team subsequently completes T12, replace this with the actual observed sources and hardware results.

**65–110 seconds.** Start the standard replay. “This is DEMO 4x, a three-minute simulated scenario. The heart rate stays above the example band, so the app first suggests easing off, then a walk break. It waits for lower HR and a minimum walking interval before offering a return to running. The scripted acceptance demonstrates that choice.”

**110–140 seconds.** “The useful behavior is the timing and explanation of the suggestion. A missing HR signal disables the return-to-run offer. Pause freezes progress, and walking still contributes to the session goal. These are experimental rules, not a fatigue or hydration diagnosis.”

**140–165 seconds.** “Our tests execute the same Monkey C filtering, rules, and controller used by the app. They check the exact replay timing, noisy and missing data, recovery, pause, manual controls, completion, storage handling, and alert deduplication.”

**165–180 seconds.** “Next we would test the suggestions on hardware and with beginners, tune the heuristics, and assess whether the experience helps people finish a manageable session. Try the missing-sensor replay and see how it responds.”

Do not claim four demonstrated sensors until HR, qualified GNSS, raw acceleration, and pressure have each been observed on the physical watch.
