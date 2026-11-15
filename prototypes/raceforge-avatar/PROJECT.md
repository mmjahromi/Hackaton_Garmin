# PROJECT.md — RaceForge Avatar: The Living PacePilot Companion

**Hackathon:** Tech Thursday × Garmin, November 14, 2026\
**Owner:** Avatar/UX development track, independent of PacePilot's sensors and coaching engine\
**Device:** Garmin Fēnix 7 Pro, 260 × 260 round MIP display\
**SDK:** Connect IQ 9.1.0; target `fenix7pro_sim` verified in previous exercises\
**Primary deliverable:** A playable, animated **Monkey C avatar prototype** integrated or ready to integrate with teammates' PacePilot.\
**Reference:** `PacePilot_Architecture_Plan.pdf` (shared team specification; especially pp. 3–5, 8–10, 13).

## One-line pitch
**PacePilot tells you what to do; RaceForge makes that guidance feel human, encouraging, and fun.**

## Product problem
Beginner runners can see heart-rate numbers and receive alerts, but a number or generic beep may not feel relatable or motivating. For people trying to stay active, an expressive coach can translate a training suggestion into a quick, emotionally understandable action without punishing walking and recovery.

## Scope, non-goals, and separation
**Build now:** A small animated running companion with distinct idle, easy effort, easing, walking, ready-to-run, paused, HR-missing, and celebration states. Use easy-to-read text as the primary instruction and animation as supportive reinforcement. Standalone scripted DEMO must run offline on the Fēnix 7 Pro simulator.

**Integrate next:** Drive avatar states from PacePilot's shared `Decision` and `Lifecycle`, with `Features.hrBpm` and `hrReady` only as displayed values. The avatar must never decide HR thresholds, alter advice, manage live sensors, or trigger haptics independently.

**Later vision only:** An evolving mountain/summit map, character outfits and achievements tied to workouts, fueling/recovery missions, multi-week training plans, body-composition customization. Do not delay today's avatar deliverable for these.

## Creative direction
Visual style: charming 2D game character, bold clear silhouette, restrained teal/orange/white palette with high contrast on black. Expression is readable at wrist distance: raised/angled eyebrows, posture, arm swing, breathing puff and sweat drop only for sustained coaching transitions. Avoid stigma: no 'fat', 'lazy', or shame states. Walking and recovery are positive choices; finishing gets a cheerful celebration.

### Main interaction storyboard
1. **READY:** Avatar stands at trail basecamp, cheerful wave. Text `START MISSION`.
2. **RUN_EASY:** Gentle looping jog; centered text `NICE & EASY`; current `HR 130` if provided.
3. **EASE_OFF:** Slower arm swing, eyebrows tilted, one puff line near mouth; text `EASE OFF`.
4. **WALK:** Slow walk, puff and one sweat droplet; text `WALK BREAK`.
5. **READY_TO_RUN:** Upright, small smile, thumbs-up; text `READY? YOUR CHOICE`.
6. **PAUSED:** Static, breathing calmly; text `PAUSED`.
7. **COMPLETE:** Arms raised, 2 celebratory sparkles, text `MISSION COMPLETE`.
8. **HR MISSING:** Neutral avatar with small `?`; text `HR UNAVAILABLE`.

## Layout prototype (round 260 × 260)
```
             [DEMO]                   y≈26
        ┌────────────────┐
        │   animated     │            central y≈75..165
        │    runner      │
        └────────────────┘
           EASE OFF                   y≈181
          HR 150 BPM                  y≈207
      [tiny state indicator]          y≈226
```
Use actual `dc.getWidth()/getHeight()`. Text/pose must not clip at curved edges. The first successful milestone is readable action + avatar; a fancy background is optional.

## The mountain-map vision (stretch; do not build first)
A compact illustrated path climbs from base camp to race summit. Waypoints represent positive training milestones, e.g., easy movement, recovery, consistent sessions, race preparation. The avatar moves between checkpoints following confirmed mission completions, not raw HR or fictional fitness improvements. Recovery may be a scenic alternate route rather than losing progress. Map is a **second screen** or end-of-session reward—not the active running screen, where the instruction must be prominent.

## Data contracts and integration
These keys are inherited from the teammate document and are not free to reinterpret:

```
Features = {
  :nowMs => Number, :hrBpm => FloatOrNull,
  :hrReady => Boolean, :speedMps => FloatOrNull,
  :movement => :MOVING_or_STILL_or_UNKNOWN,
  :terrain => :UP_or_DOWN_or_FLAT_or_UNKNOWN,
  :sourceStatus => Dictionary, :mode => :LIVE_or_DEMO
}
Decision = {
  :advice => :RUN_EASY_or_EASE_OFF_or_WALK_or_READY_TO_RUN,
  :reason => Symbol, :decisionId => Number,
  :canResumeRun => Boolean
}
Lifecycle = :READY | :ACTIVE | :PAUSED | :COMPLETE
```

These are contract sketches, **not valid Monkey C type aliases**. The avatar adapter should map source fields to a small render model. Priority: COMPLETE > PAUSED > HR missing (when ACTIVE) > advice state > READY. Do not infer that a person is genuinely tired from HR alone. The phrase “winded” describes a character pose associated with coach's action.

**Proposed presentation model:**
```
AvatarModel = {
  :pose => :IDLE | :JOG | :EASE | :WALK | :RECOVER | :REST | :CELEBRATE | :UNKNOWN,
  :headline => String,
  :hrText => String,
  :modeText => "LIVE" | "DEMO",
  :frame => 0 | 1 | 2 | 3,
  :reasonText => String,
  :decisionId => NumberOrNull
}
```

**Suggested integration API (confirm exact class signature with team):**
- `AvatarAdapter.fromSnapshot(features, decision, lifecycle, frameIndex)` produces model.
- `AvatarRenderer.draw(dc, model, left, top, width, height)` draws inside allotted bounds.
- The PacePilot view owns refresh frequency and overall app navigation. We do not duplicate session or sensor services.

**Avoid branch conflicts:** Only export the reusable renderer, adapter/model and resources. Keep `raceforgeAvatarApp.mc`, `raceforgeAvatarView.mc`, and delegate in the stand-alone prototype branch. Coordinate with team member owning the PacePilot view before editing it.

## Animation mechanics
Prototype with native `Graphics.Dc` primitives: head circle, eyes, brows, torso rectangle/polygon, arms/legs as lines, puff arcs, sweat droplets. Choose two key poses for jog (alternating limb angles), two for walk, two for effort/puff; otherwise static. Timer-driven redraw at about 2 Hz only when view is active. When paused, use a static pose. Limit allocations and clear only the designated avatar area if embedded. No downloaded animation dependencies.

**Demo controller:** START cycles through scripted phases; deliberately expose `DEMO`. Optional synthetic HR labels 130 → 150 → 160 → 130 → 130 → -- for phases. These are representative demonstration inputs, not automatic zone classification. The actual PacePilot coach engine alone owns state transitions. If integrating its deterministic 180-s replay at 4×, let its decisions drive our animation.

## Acceptance criteria
- [ ] Compiles and launches for `fenix7pro_sim` under SDK 9.1.0.
- [ ] Character and headline visible at wrist-readable size, no circular-edge clipping.
- [ ] START cycles through at least five distinguishable expressions.
- [ ] Legs/arms move between frames in jog/walk states; effort includes puff/sweat.
- [ ] PAUSED/COMPLETE/HR UNAVAILABLE render accurately and don't misrepresent evidence.
- [ ] Demo is clearly labeled and works without real sensors or a physical watch.
- [ ] Animation timer stops on `onHide()`/exit; no duplicate callback on return.
- [ ] Adapter can consume canonical shared dictionary keys without changing PacePilot engine.
- [ ] The team can import reusable files into the primary app without copy-pasting a second app class.

## Four-hour delivery plan
| Gate | Goal | Cut if behind |
|---|---|---|
| First 15 min | Garmin shell compiles on target | No design polish |
| 15–45 min | Draw avatar + pose variants | Replace PNG art with primitives |
| 45–75 min | Scripted states, buttons, on-screen text | No extra gestures |
| 75–105 min | Animation and cleanup | Fewer frames |
| 105–135 min | Read-only adapter + integration handoff | Screen-only mock input |
| 135–165 min | Team integration and simulator verification | Keep demo standalone |
| Last 30–45 min | Freeze, screenshots, record backup, pitch | No extra roadmap features |

## Three-minute pitch contribution (avatar segment, ~15 seconds)
"PacePilot makes adaptive decisions using available effort and motion data. RaceForge is how those decisions come alive on the wrist: our runner relaxes during comfortable effort, visibly eases off when the coach advises it, takes a walk break, and celebrates finishing. The interaction stays positive—walking and recovery count as progress."

**Claim discipline:** An expressive avatar is an experimental engagement design; user motivation and behavior outcomes have not been measured. The demo is not fatigue diagnosis. A simulator demonstration is not proof of hardware deployment.

## Implemented milestone 2 — November 14, 2026

See `MILESTONE2.md` for current controls, verification results and integration.
The original sections above remain the initial specification; this section records
the implemented architecture and supersedes the proposed timer/model details.

- Original outlined procedural artwork, four running/walking poses, starting
  crouch, breathing, sweat, effort expressions and short celebration with final hold.
- Standalone view owns one 250 ms timer and one retained complete-frame drawing
  surface. Hidden, frozen and static modes stop the timer; completion stops it
  after the brief celebration. Scene/animation time comes from elapsed time.
- START skips scenes, UP switches easy/tempo/static modes, DOWN freezes/resumes;
  the native menu also exposes these choices. All scripts are explicitly DEMO.
- `RaceForgeAvatarAnimator` animates retained models; optional speed influences
  bounded visual cadence, not measured step frequency. STILL stops locomotion.
- `RaceForgeAvatarAdapter` reads canonical Features/Decision/Lifecycle. Live
  defaults follow the existing advice, without HR thresholds. Optional workout
  presentation context is separate from the frozen shared dictionaries.
- Only the demo context interprets configurable illustrative HR ranges. Scripted
  advice is supplied independently; a high HR cannot create EASE_OFF or WALK.
- Transfer model, renderer, animator, adapter and workout context. Keep App,
  View, delegates, demo controller and test files in this standalone prototype.

## Implemented milestone 3

The weekly-adventure entrypoint now wraps the existing avatar. See README.md and
MILESTONE3.md for current controls, 21 simulator tests and integration ownership.
A small summit and four/five real plan checkpoints lead through mission selection,
shared-controller workouts, explicit completion and persistent LIVE progress.
First-launch personalization, local check-ins and confirmed missed/fatigue options
are implemented. DEMO progress is separate and temporary. The actual shared HR/
GPS provider, pipeline, coach, clock and alert service are imported unchanged.
Only weekly activity is implemented; other race journeys and web exchange are future.
