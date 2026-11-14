# AGENTS.md — RaceForge Avatar Prototype

## Mission and constraints
You are the lead Monkey C engineer for **RaceForge Avatar**, a standalone visual prototype to be merged into teammates' **PacePilot** Fēnix 7 Pro Connect IQ watch app. Work quickly toward a compilable, visually expressive, testable 260 × 260 round-screen demo. This module is **presentation and interaction**, not another coaching engine.

- Exact local SDK: **Connect IQ 9.1.0**; simulator target used in prior builds: `fenix7pro_sim` (confirm actual target in project output); watch: standard **Fēnix 7 Pro**, API 5.2 device profile.
- Use **Monkey C** and Garmin-native APIs supported by the installed SDK. Create a **Watch App / Simple** project with Garmin's official VS Code extension.
- No network, phone companion, machine learning, medical inference, proprietary Garmin algorithms, health-data uploads, or cloud dependency.
- The working simulator demo is the mandatory deliverable. Physical-device validation is separate; never claim it if untested.
- Use simple primitives and/or tiny optimized PNG sprite sheets; no heavy graphics libraries, 3D, GIF decoding, or excessive redraws.
- Do not modify teammates' code, sensors, `CoachEngine`, `FeaturePipeline`, `SessionController`, or `Contracts` from a separate avatar branch without coordinating.

## Read first
1. `PROJECT.md` in this folder (feature and screen specification).
2. `PacePilot_Architecture_Plan.pdf` if available to you; if not, use the integration contract documented here and request the current shared contract from teammates before the final merge.
3. The generated `manifest.xml`, `monkey.jungle`, and four generated Monkey C source files. Preserve the generated app entrypoint and resource names where possible.
4. Inspect SDK examples/reference code before calling uncertain Toybox APIs. Do not invent API signatures. Compile early.

## Shared PacePilot contract — frozen semantics
The team plan defines these data structures as Monkey C **dictionary notation**, not copy-paste type syntax:

- `Features`: `:nowMs`, `:hrBpm` (Float or null), `:hrReady` (Boolean), `:speedMps`, `:movement`, `:terrain`, `:sourceStatus`, `:mode` (`:LIVE` or `:DEMO`).
- `Decision`: `:advice`, `:reason`, `:decisionId`, `:canResumeRun`.
- Advice symbols: `:RUN_EASY`, `:EASE_OFF`, `:WALK`, `:READY_TO_RUN`.
- Lifecycle: `:READY`, `:ACTIVE`, `:PAUSED`, `:COMPLETE`.
- Sensor status: `:VALID`, `:STALE`, `:MISSING`, `:UNSUPPORTED`, `:ERROR`.
- `:hrBpm == null` means **unknown**, NOT zero. On unavailable or not-ready HR do not show a physiological fatigue expression; show neutral/avatar sensor-loss treatment.
- LIVE and DEMO must be visibly differentiated. DEMO values are synthetic, never silently called live measurements.
- Page 8-9 team rule engine is the sole source of advice transition decisions. In the shared app, never compute `EASE_OFF` or `WALK` from an arbitrary HR cutoff in the avatar.

## Integration architecture
Build a **presentation-only adapter** that receives a snapshot from PacePilot and produces a render model:

```
PacePilot Features + Decision + Lifecycle
             ↓
AvatarAdapter.fromSnapshot(...)    # proposed helper; agree on real signature at merge
             ↓
AvatarModel { mood, motion, hrText, prompt, mode, reason, phase, frameIndex }
             ↓
AvatarRenderer.draw(dc, model)
             ↓
PacePilot existing view (embedded widget or separate full-screen view)
```

Keep renderer free of sensor acquisition, coaching logic, persistent data writes, and `WatchUi.requestUpdate()` calls. The **parent/controller** requests redraw. The renderer draws only within given bounds and never overrides the entire PacePilot view when embedded. Make the adapter thin and deterministic. Accept a synthetic `AvatarModel` directly for standalone demo.

### State mapping
| Shared state | Mood | Motion | On-screen phrase |
|---|---|---|---|
| `ACTIVE + RUN_EASY` with valid HR | calm | easy jog | `NICE & EASY` |
| `ACTIVE + EASE_OFF` | exerted | slower jog, short puff lines | `EASE OFF` |
| `ACTIVE + WALK` | winded | walk, sweat/puff cycling | `WALK BREAK` |
| `ACTIVE + READY_TO_RUN` | encouraged | upright recovery | `READY? YOUR CHOICE` |
| `PAUSED` | resting | still | `PAUSED` |
| `COMPLETE` | celebrating | arms up (short loop) | `MISSION COMPLETE` |
| HR `null`, stale, missing or `hrReady=false` while ACTIVE | neutral | neutral/idle | `HR UNAVAILABLE` |
| `READY` | neutral | idle | `START MISSION` |

**Important:** 'winded' is an expressive metaphor for the coaching suggestion, not a diagnosis of actual fatigue. The avatar does not become thinner or more muscular from HR or workout volume. Future physique customization must require measured/manual body-composition data and user choice.

## Standalone demo controls
Do not duplicate the full PacePilot session rules. Provide a user-accessible, prominently labeled **DEMO** mode to cycle scripted avatar states. Prefer:
- START: advance scripted phase (READY → RUN_EASY → EASE_OFF → WALK → READY_TO_RUN → COMPLETE → READY).
- UP/DOWN: optionally adjust synthetic HR for display; must NOT change advice independently of the selected scripted phase. Or use these buttons for previous/next phase if more reliable.
- BACK: return to introductory view via normal Garmin flow.
- Display `DEMO` badge at all times in scripted mode and include `HR --` where no synthetic HR is provided.

After initial proof, add a timed deterministic replay driven by the *same* phases the team uses: comfortable (130 bpm), sustained high effort (150 bpm), walking/recovery (130 bpm), goal completion. The teammate team plan specifies a separate 180-s scenario at 4× playback; do **not** implement the engine again. If merging, subscribe to their `Decision` output instead.

## Visual design for 260 × 260 MIP circle
- Read `dc.getWidth()` and `dc.getHeight()`; use centered composition and keep critical text within a conservative circular safe region (roughly x=40..220 near middle; tighter near top/bottom).
- Prioritize the **avatar silhouette and one action**. Suggested arrangement: top `DEMO`/`LIVE` label, centered avatar occupying ~90×100, below large action words; HR shown as short label when available.
- Implement all avatar poses from **reusable primitive shapes** first (head, body, arms, legs, eyes, smile, sweat droplets, puff curves). Color is secondary: state must also be distinguishable by pose and wording.
- Avoid strobe, excessive blinking, and implying alerts that did not occur. Keep animation at ~2–4 visual poses per second at most for demo, or slower (1–2 Hz) if memory/performance requires it. No raw frame history.
- Use on-device drawable assets only if primitives are insufficient. PNGs must be small and authored with transparent pixels where useful.
- No cropping at circle edges; test each state at target size. Handle null HR and missing sensor status.

## Proposed file ownership (rename to match existing generated app)
```
source/
  raceforgeAvatarApp.mc        # standalone demo composition only
  raceforgeAvatarView.mc       # demo screen and redraw ownership
  raceforgeAvatarDelegate.mc   # physical buttons (only in standalone demo)
  AvatarModel.mc               # state → display data (no Garmin sensor APIs)
  AvatarRenderer.mc            # draw to Graphics.Dc; export for embedding
  AvatarDemoController.mc      # deterministic scripted model sequences
resources/...
PROJECT.md
AGENTS.md
.gitignore
```

Use unique `RaceForgeAvatar*` prefixes where appropriate to avoid clashing with PacePilot's classes. The generated fourth `*MenuDelegate.mc` should remain if unused; never define a duplicate delegate class in the view file (a prior project encountered that exact build error). During integration, **only transfer `AvatarModel`/`AvatarRenderer` and optional adapter** unless the team explicitly asks for demo UI classes.

## Build-first sequence and gates
1. **0–15 min:** Generate a Watch App; compile untouched shell on `fenix7pro_sim`.
2. **15–45 min:** Draw expressive idle, jog, winded, walk, celebration poses via primitives. Build + simulator screenshot. **Gate A: avatar visible, no clipping.**
3. **45–75 min:** Add DEMO state transitions and live HR label *as data only*. **Gate B: each state can be reached using buttons, with appropriate text.**
4. **75–105 min:** Simple arm/leg offset animation, puff/sweat shapes, 1–2 Hz tick and redraw; lifecycle teardown stops timer. **Gate C: no crashes after repeated navigation.**
5. **105–135 min:** Add pure adapter matching teammates' contract; send them API contract and screenshot/GIF. **Gate D: standalone branch remains buildable.**
6. **135–165 min:** Merge in a teammate-owned integration branch, or hand over the component without blocking. **Gate E: shared app drives avatar from real `Decision`.**
7. **Final 30–45 min:** Freeze features, test missing HR and paused/completed states, record backup demo, rehearse 10–20 sec avatar segment for three-minute team pitch.

The above is a relative timebox; prioritize correctness and team readiness over completing every stage.

## Acceptance checks
- A0: Garmin build succeeds on exact target; source is committed, signing key excluded.
- A1: Every scripted state renders readable text and identifiable expression.
- A2: Animation starts and stops cleanly; no render work when hidden; no duplicate timers.
- A3: `DEMO` unmistakable; HR missing is `--` and does not imply danger or recovery.
- A4: Avatar reacts to **advice transitions**, not independent HR thresholds.
- A5: Live integration uses existing `Features` and `Decision` semantics, including `decisionId`, if available.
- A6: Frame rendering and state changes use bounded work and don't damage PacePilot's primary instruction visibility.
- A7: Final proof distinguishes simulator, replay, and physical-watch verification.

## Handoff contract to teammates
Send: `AvatarRenderer.mc`, `AvatarModel.mc`, `AvatarAdapter.mc` if created, any small image resources, compile instructions, `avatarIntegrationExample()` pseudocode, screenshots/short video, known limitations, Git commit hash. Teammates should be able to call `AvatarRenderer.draw(dc, avatarModel, bounds)` (proposed signature) from their existing `PacePilotView`, not replace its session controller. Coordinate the exact signature and layout ownership with UI owner C before merging.

## Code-agent behavior
- Inspect actual file contents and imports before editing; change the smallest surface area.
- Work one buildable milestone at a time; fix compiler errors from exact log lines.
- Never invent a Garmin API or report a build as passing without the simulator/terminal evidence.
- When requiring integration changes, produce a patch or concrete handshake request rather than guessing teammates' latest code.
- Explain precisely what was implemented, what is only simulated, and what needs merging.

## Milestone 3 scope update

The user's milestone-3 brief expands this prototype into a weekly fitness adventure.
RaceForge owns AdventureController/View/Session bridge, WeeklyJourney, JourneyStorage
and SummitRenderer. The five existing avatar components remain presentation-only.
Import the shared PacePilot modules via explicit source paths; do not edit them or
implement another coaching clock/engine. LIVE uses the shared provider and declared
Sensor/Positioning permissions. Store only bounded, versioned string-key summaries,
manual profile/check-ins and explicit achievements. DEMO must never update real
exercise progress. See MILESTONE3.md for tested semantics and current limitations.
