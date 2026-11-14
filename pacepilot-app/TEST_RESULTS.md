# PacePilot verification

Date: 14 November 2026. Implementation commit: `5c6e67eec3557a9cf35be9ca7fcf88e8ab286e21`.

SDK 9.1.0, installed `fenix7pro` device profile, API 5.2, 260 × 260. Manifest minimum API 3.2.0.

Both production and unit-test builds printed BUILD SUCCESSFUL. Garmin's Monkey C unit-test runner executed 29 tests in the Fenix 7 Pro simulator and printed **PASSED (passed=29, failed=0, errors=0)**. The raw log is in `tests/simulator-results.txt`. Binary and source fingerprints are in `release/SHA256SUMS.txt`.

The production build was also submitted with `monkeydo bin/pacepilot.prg fenix7pro`; the command completed successfully. No screenshot or visual inspection was performed. This is simulator-tested software with physical acceptance incomplete.

All rows below refer to implementation commit `5c6e67e`.

| Test | Environment | Expected | Observed | Result |
| --- | --- | --- | --- | --- |
| T01 | Fenix 7 Pro simulator unit runner | Feature thresholds at 15/60; raw replay at 36/81/141/160 and goal 180 | Exact sequence asserted through production filtering/controller | PASS |
| T02 | Simulator unit runner | Isolated spike filtered; alternating high/low cannot accumulate high dwell | Median 130; remains RUN_EASY | PASS |
| T03 | Simulator unit runner | Both walk/recovery holds required; high HR or STILL revokes offer | Boundary, rejection, UNKNOWN motion, acceptance assertions pass | PASS |
| T04 | Simulator unit runner | Loss across advice states; stale/null suppression; fresh reacquisition; unique samples; valid status | Loss, stale/future/out-of-range data, cached samples, source errors, and loss replay pass | PASS |
| T05 | Simulator unit runner | Pause freezes progress; resume rejects cached HR; gaps/rollback credit nothing | highSec 14 pause case, post-resume samples, time-gap and rollback assertions pass | PASS |
| T06 | Simulator unit runner | Manual WALK without HR; END precedence; duplicate events; mode guard; restart | Assertions pass | PASS |
| T07 | Simulator unit runner | Complete once at goal; unknown movement earns no moving time | Exactly 60 session seconds, zero moving seconds, one summary write | PASS |
| T08 | Simulator unit runner with drawing probe | Null display data; pause/end controls; render all replay states | Null statuses and control states pass; all draw paths execute | PASS for logic/render-call execution |
| T08 visual | Human inspection on target display | Readable text and layout on round display | Not inspected by eye; measured-width fitting implemented | NOT RUN |
| T09 | Simulator unit runner | GPS/accel fallback, conflicting votes, invalid arrays | Moving/still/unknown fusion and RMS reduction pass | PASS |
| T10 | Simulator unit runner | Qualified trend only; deadband/loss reset; no HR timing changes | UP/FLAT, deadband, stillness/loss and timing assertions pass | PASS |
| T11 | Simulator unit runner | Corruption safe; failed write retains summary; demo isolated; alerts deduplicated | Serialization/validation, fake failed write, no demo writes, cooldown gate pass | PASS for tested boundaries |
| T11 physical | Watch | Persistent storage across relaunch and actual haptic delivery | No mounted watch available | NOT RUN |
| T12 | Physical Fenix 7 Pro | Launch, live HR, all controls, pause/resume, completion, exit/relaunch and cleanup | No physical device mounted or tested | NOT RUN |

T08 rendering uses a fake drawing context and does not verify actual pixels. T11 failure tests inject a failing store; they do not prove every device storage exception. Alert tests verify eligibility and deduplication without requiring vibration hardware.

## Verified sensor inventory

| Source | Integration | Observed on physical watch |
| --- | --- | --- |
| Wrist HR | Onboard sensor API, enabled-list check, stale/null handling | NOT RUN |
| GNSS | Continuous location, quality and advancing fix timestamp checks | NOT RUN |
| Accelerometer | 25 Hz raw arrays reduced to bounded RMS statistic | NOT RUN |
| Barometer | Sensor.Info pressure, bounded window and trend qualification | NOT RUN |

Live sources demonstrated on hardware: **zero verified so far**. Synthetic replay proves algorithm behavior. FIT is disabled and no recording save is claimed.

## T12 operator checklist

1. Install the production .prg on the exact device.
2. Confirm the chosen HR band and a short goal in LIVE.
3. Observe HR acquisition and each available source badge. Record readings as available or unavailable.
4. Request a walk, pause, resume, open/cancel End, and complete or end.
5. Verify goal time freezes while paused and resumes with fresh HR acquisition.
6. Relaunch and check the saved LIVE summary. Run DEMO and verify it does not replace that summary.
7. Exit and confirm sensor subscriptions stop. Exercise missing-HR behavior.
8. Record device model, firmware, commit, actual observations, and pass/fail.

Software unit gates pass. Physical acceptance remains incomplete until T12 is observed.
