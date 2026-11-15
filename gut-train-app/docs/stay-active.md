# Local daily activity — SDK notes and verification

Implemented against the installed Connect IQ SDK 9.1.0, fenix7pro, minimum API 5.2.0.
These notes describe the local daily activity subsystem, not the newer dashboard daily-plan engine. See [STATUS.md](../../STATUS.md) for the complete current implementation and evidence. Gut Train now uses explicit next-target confirmation; its session controls and sharing have changed since these notes were first written.

## SDK references checked during the original implementation

Paths below are relative to the SDK selected by `current-sdk.cfg`:

- `doc/Toybox/ActivityMonitor.html`: `getInfo()` and `getHistory()`. History is an array of **at most seven days**, newest first.
- `doc/Toybox/ActivityMonitor/Info.html`: `activeMinutesDay`, `steps`, `floorsClimbed`, `moveBarLevel`; check nullable sensor values.
- `doc/Toybox/ActivityMonitor/History.html`: `startOfDay` and `activeMinutes` support date-filtered Monday–Sunday sums. Partial history is summed without extrapolation.
- `doc/Toybox/ActivityMonitor/ActiveMinutes.html`: `total` is moderate minutes plus twice vigorous minutes. Both daily display and weekly adaptation use this Garmin total.
- `doc/Toybox/SensorHistory.html` and `SensorHistory/SensorSample.html`: `getBodyBatteryHistory({:period=>1, :order=>ORDER_NEWEST_FIRST})`; `data` may be null, `when` identifies the sample date. Requires SensorHistory permission. Only a current-day, non-future morning sample in 0–100 is accepted. One read attempt before 11:00 each local day; missing stays null.
- `doc/Toybox/Background.html`: repeating `Time.Duration(1800)` temporal event; five-minute minimum; only one temporal registration. `requestApplicationWake` is for a background watch-app/widget task, and the dialog appears only after `Background.exit`. Message limit 255 bytes; exit data limit approximately 8 KB.
- `doc/Toybox/System/ServiceDelegate.html`: asynchronous Communications work may be started in the delegate, but only the delegate invocation is guaranteed to complete; the OS may terminate the service early.
- `doc/Toybox/Communications.html`: JSON POST requires the JSON Content-Type header and asynchronous callbacks. This describes the original upload design; current `ActiveSync` performs no request and invokes its callback locally, allowing the service to exit.
- `doc/Toybox/Time/Gregorian.html`: `info` uses local time, `moment` interprets supplied fields as UTC, `utcInfo` reads UTC. Local Y/M/D is encoded as a civil UTC-midnight token for calendar arithmetic. This avoids DST changing week/date boundaries when subtracting days. Tokens are not real local-midnight timestamps.
- `doc/Toybox/Application/Storage.html`: background writes/deletes require API 3.2+, supported by this device. Keys are strings, never symbols. `activeWeek` atomically stores Monday token/date, target and minutes before today. `activeDay`, battery and nudge keys reset on a local-date change. Gut programme storage is separate.
- `doc/docs/Core_Topics/Backgrounding.html`: only annotated code is included in the service; related modules, service and AppBase must carry `(:background)`. Services may be killed early and are terminated after 30 seconds. The service uses ActivityMonitor, SensorHistory, Storage, Gregorian, Communications and Background; it does not call foreground drawing, timers, recording or live sensor registration. The annotation makes code available; it does not make foreground-only APIs legal. AppBase foreground methods produce the expected scope warnings, as in breathe-app.
- `doc/docs/Device_Reference/fenix7pro.html`: **background memory limit 65,536 bytes (64 KiB)**. Keep demo data, views, session logic and tests out of background code. Runtime peak memory still needs device verification.

## Behaviour and deliberate limits

- Weekly target starts at 150. A new Monday rolls it once using the immediately previous week's available history. After a long absence, no synthetic empty weeks are replayed. Same-week reopening does not roll again.
- Normal daily target has a floor of 10; recovery is applied afterwards, so its minimum is 6, per the contract's ordering.
- Missing steps, active minutes or floors show `--`; missing Body Battery remains null. `ActiveData.ready()` retains the whole-number readiness checks, but current `ActiveSync.post()` makes no network request and immediately invokes its callback with 204. Daily activity stays on the watch.
- Nudge hours are 08:00 inclusive to 21:00 exclusive, local time. Movement responses are **approximate**: a gain of at least 200 steps by the next run within 30 minutes is used as a proxy for the requested 15-minute response. Thirty-minute snapshots cannot establish which half of the interval contained those steps. Old pending nudges are consumed once and never credited after that window or across dates.
- Home demo fills only missing sensor fields. In that case it shows 18/30 minutes, 6240 steps, 7 floors and 96/150 week minutes. Valid real zero readings remain zero. A real-time five-second timer dismisses the demo banner. The demo helper still builds seven labeled synthetic day records, including one recovery day, but routes them through the disabled `ActiveSync.post()`; no records are uploaded and LIVE week/target storage is preserved.
- Day/demo callback codes can still be logged, but 204 here is the local disabled-upload result, not proof of server delivery. Background nudges and local bookkeeping remain best effort under Garmin OS lifecycle limits. There is no historical offline upload queue.
- The legacy `/api/days` endpoint still upserts by date and can contain older records. Current watch daily/demo paths do not send to it.

## Historical verification notes

The statements below describe the original daily-activity implementation pass, not current suite execution or unchanged-file guarantees. Current evidence and limits are recorded in [STATUS.md](../../STATUS.md#verification-evidence).

- `ActiveTest.mc` covers all adaptation branches, exact 80%/100% boundaries, nearest-five rounding including ties, 60/300 limits, daily ceiling/floor, recovery threshold/null, recovery floor ordering and civil week/date boundaries.
- Both requested `monkeyc` builds (normal and `-t`) are required. `-t` compiles the test program; it does **not execute** tests. Runtime Monkey C tests, visual/button checks, wake dialogs, sensor values, HTTP delivery and peak memory require a simulator/device. The simulator was deliberately not started.
- SHA-1 checks against pre-change copies verify Plan, SessionView, RatingView, SummaryView, Sensors, SensorsTest and TooShortView were not changed. Session mappings and summary keys, including omission of unread temperatures, are preserved.
