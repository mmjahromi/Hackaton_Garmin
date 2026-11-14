# Gut Train

A Garmin Fenix 7 Pro watch app for following your chosen fueling routine and recording what you tolerated during activity. It runs separately from PacePilot; both can share summaries to the same dashboard.

## Nutrition flow

1. From the activity home, START opens your fuel plan.
2. UP/DOWN adjusts each choice; START confirms: target (30–90 g/h), food type (gel, chews, drink, food), carbohydrates per portion (5–60 g), drink cue interval (off, 10, 15, or 20 minutes), and optional public sharing. Use a plan appropriate to you; the app does not calculate physiological needs.
3. During the session, START/STOP stops or resumes the timer. Hold UP/MENU (or press UP/DOWN) opens tasks and stops the workout. Choose Log food portion, Log drink (150 ml), Flag gut discomfort, Resume workout, or Finish workout. BACK asks for confirmation before finishing. Menu dismissal leaves the timer stopped; START resumes it. Food log details retain the first 32 entries; aggregate totals continue counting afterward.
4. Sessions of at least ten minutes proceed to gut comfort (1–5), then a next target that you explicitly confirm. A good rating no longer automatically raises the target.
5. The last 20 LIVE nutrition summaries are stored locally. When opted in, the summary also appears on the shared dashboard. There is no offline upload queue or later nutrition-history upload screen.

Daily activity stays local; background and demo-day uploads are disabled. DEMO sessions do not change stored goals or upload summaries. Sharing defaults off each session. Shared summaries are publicly readable on the hackathon dashboard.

Drink cues follow the interval you choose. Wrist temperature is recorded when available but no longer changes the drink schedule. The app does not diagnose dehydration, gut disease, fatigue, or recovery.

## VS Code and builds

Install Garmin’s Monkey C extension and Connect IQ SDK 9.1.0 with the `fenix7pro` device profile. Open this folder in VS Code, run **Monkey C: Verify Installation**, and configure your private developer signing key. Do not commit the key. The neighboring `pacepilot-app/README.md` has detailed SDK/VS Code setup instructions.

On this Mac:

```sh
SDK="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
mkdir -p bin
"$SDK/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/guttrain.prg -y "$HOME/.garmin/developer_key.der" -w -l 0
"$SDK/bin/monkeyc" -d fenix7pro -f monkey.jungle -o bin/guttrain-test.prg -y "$HOME/.garmin/developer_key.der" -w -l 0 -t
"$SDK/bin/connectiq"
"$SDK/bin/monkeydo" bin/guttrain-test.prg fenix7pro -t
```

Both builds compile. All 25 tests pass in the simulator for this revision; see `tests/controls-simulator-results.txt`. Native menu interaction and device sensor/haptic behavior still need acceptance testing. No physical-watch or visual validation has been performed for this revision. Sideload the production PRG into `GARMIN/APPS` using Garmin’s supported USB workflow and verify sensor permissions, buttons, cue timing, offline storage, and explicit sharing before presenting a hardware demo.

Dashboard instructions: `../gut-train-web/README.md`.

## App switching and LIGHT

Hold UP/MENU from the home screen to select Open PacePilot. During a workout, switching is blocked until it is finished; return home after the summary to switch. Both apps must be installed. Garmin supplies the switch confirmation; failure leaves the current app open. The LIGHT key keeps its native behavior. The new configurable HR band indicators belong to PacePilot; Gut Train retains its existing high-HR feeding advice.

The redesigned visual UI is reserved for Claude. See `../CLAUDE_HANDOFF.md` for the remaining design and validation work.
