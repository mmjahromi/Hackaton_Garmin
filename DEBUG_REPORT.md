# Functional debugging report

Date: 14 November 2026.

| Area | Result |
| --- | --- |
| PacePilot simulator suite | 36 passed, 0 failed |
| Gut Train simulator suite | 28 passed, 0 failed |
| Dashboard/API suite | 54 passed, 0 failed |
| Isolated real-Redis integration | 1 passed, 0 failed |
| Both watch production/test builds | Successful, SDK 9.1.0, fenix7pro |
| Next.js production build | Successful |
| Local production HTTP checks | Invalid nutrition payload rejected; valid nutrition saved; active/paused/completed live updates accepted; delayed reopening rejected |

## Fixed

- A haptic transition could be permanently dropped when first encountered during cooldown. Only actually emitted cues are now deduplicated; a still-relevant cue can fire after cooldown.
- Gut Train could publish cached HR/speed immediately after resume. Readings are cleared on resume, and both telemetry senders suppress cached readings on direct or queued paused-to-active transitions.
- The nutrition API accepted null, booleans, blank strings and arrays as numeric values. These now return400; legitimate zero and numeric strings retain compatibility. The added regression failed before the fix and passed afterward.

The Redis test executes the production Lua script against a temporary local Redis. It checks concurrent ordering, duplicate suppression, completed-session protection, channel isolation, bounded history and TTL configuration. It never touches the production database. Initial Unix-socket binding was unavailable in this environment; the test uses an isolated password-protected loopback port.

The simulator initially timed out for PacePilot; a retry ran all36 tests successfully. Current raw simulator logs are under each app's `tests/debug-simulator-results.txt`. Previous logs are historical evidence.

## Remaining acceptance

No physical Garmin/phone session was performed. Actual button/menu interactions, app switching, haptic feel, real sensor freshness, phone connectivity and display readability need device acceptance. No screenshots were taken. The requested visual redesign remains reserved for Claude.
