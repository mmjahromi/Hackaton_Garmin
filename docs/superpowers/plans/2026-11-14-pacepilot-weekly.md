# PacePilot weekly adventure integration

Goal: one PacePilot installation with RaceForge weekly missions and saved progress, preserving existing coaching, recovery, fueling and dashboard sharing.

Architecture: use RaceForgeWeeklyJourney/PlanChanges/JourneyRepository and SummitRenderer through explicit build paths. Add a PaceWeekly adapter for browsing, profile setup, confirmations and persistence. Mission selection sets the existing PacePilot session duration; the existing controller/provider remains the sole workout engine. Commit a mission result only at confirmed post-workout feedback. Local journey storage uses a separate PacePilot key; DEMO writes no LIVE results.

Alternatives: launching the standalone adventure would retain two apps and lose PacePilot sharing/feedback. Embedding its separate session bridge would introduce a second workout lifecycle. The chosen design reuses the current PacePilot lifecycle and the pure RaceForge journey model.

Constraints: SDK9.1.0, fenix7pro; no screenshots, production writes or private-key exposure. No automatic progression, resets or plan adjustments; preserve corrupt records and rollback on failed save. Weekly days remain relative1–7, not calendar rollover. Dashboard summary/live payloads retain their existing behavior; weekly trail itself is local.

- [x] Add a regression for Weekly adventure entry; execute and observe failure.
- [x] Add shared journey sources, adapter and integrated navigation. Existing workout menus, review sharing, recovery feedback and fuel logs remain.
- [x] Cover confirmed completion, partials, duplicate saves, DEMO isolation, restart, corrupt/failing storage, summit and adjustments, with real journey logic and injectable storage.
- [x] Build production/test apps and run full PacePilot and standalone RaceForge suites serially.
- [x] Refresh PacePilot release files/checksums, update current docs, review diff and record limitations.
