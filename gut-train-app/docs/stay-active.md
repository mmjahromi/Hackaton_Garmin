# Stay active — SDK notes and verification

Implemented against the installed Connect IQ SDK 9.1.0, fenix7pro, minimum API 5.2.0.
The gut programme and session implementation remain unchanged.

## Local SDK references checked

Paths below are relative to the SDK selected by `current-sdk.cfg`:

- `doc/Toybox/ActivityMonitor.html`: `getInfo()` and `getHistory()`. History is an array of **at most seven days**, newest first.
- `doc/Toybox/ActivityMonitor/Info.html`: `activeMinutesDay`, `steps`, `floorsClimbed`, `moveBarLevel`; check nullable sensor values.
- `doc/Toybox/ActivityMonitor/History.html`: `startOfDay` and `activeMinutes` support date-filtered Monday–Sunday sums. Partial history is summed without extrapolation.
- `doc/Toybox/ActivityMonitor/ActiveMinutes.html`: `total` is moderate minutes plus twice vigorous minutes. Both daily display and weekly adaptation use this Garmin total.
- `doc/Toybox/SensorHistory.html` and `SensorHistory/SensorSample.html`: `getBodyBatteryHistory({:period=>1, :order=>ORDER_NEWEST_FIRST})`; `data` may be null, `when` identifies the sample date. Requires SensorHistory permission. Only a current-day, non-future morning sample in 0–100 is accepted. One read attempt before 11:00 each local day; missing stays null.
- `doc/Toybox/Background.html`: repeating `Time.Duration(1800)` temporal event; five-minute minimum; only one temporal registration. `requestApplicationWake` is for a background watch-app/widget task, and the dialog appears only after `Background.exit`. Message limit 255 bytes; exit data limit approximately 8 KB.
- `doc/Toybox/System/ServiceDelegate.html`: asynchronous Communications work may be started in the delegate, but only the delegate invocation is guaranteed to complete; the OS may terminate the service early.
- `doc/Toybox/Communications.html`: JSON POST requires the JSON Content-Type header. Requests are asynchronous; service calls `Background.exit` in the response callback (also exits on missing readings or synchronous errors).
- `doc/Toybox/Time/Gregorian.html`: `info` uses local time, `moment` interprets supplied fields as UTC, `utcInfo` reads UTC. Local Y/M/D is encoded as a civil UTC-midnight token for calendar arithmetic. This avoids DST changing week/date boundaries when subtracting days. Tokens are not real local-midnight timestamps.
- `doc/Toybox/Application/Storage.html`: background writes/deletes require API 3.2+, supported by this device. Keys are strings, never symbols. `activeWeek` atomically stores Monday token/date, target and minutes before today. `activeDay`, battery and nudge keys reset on a local-date change. Gut programme storage is separate.
- `doc/docs/Core_Topics/Backgrounding.html`: only annotated code is included in the service; related modules, service and AppBase must carry `(:background)`. Services may be killed early and are terminated after 30 seconds. The service uses ActivityMonitor, SensorHistory, Storage, Gregorian, Communications and Background; it does not call foreground drawing, timers, recording or live sensor registration. The annotation makes code available; it does not make foreground-only APIs legal. AppBase foreground methods produce the expected scope warnings, as in breathe-app.
- `doc/docs/Device_Reference/fenix7pro.html`: **background memory limit 65,536 bytes (64 KiB)**. Keep demo data, views, session logic and tests out of background code. Runtime peak memory still needs device verification.

## Behaviour and deliberate limits

- Weekly target starts at 150. A new Monday rolls it once using the immediately previous week's available history. After a long absence, no synthetic empty weeks are replayed. Same-week reopening does not roll again.
- Normal daily target has a floor of 10; recovery is applied afterwards, so its minimum is 6, per the contract's ordering.
- Missing steps, active minutes or floors show `--`. No real record is posted until all three are available, because the server contract requires whole numbers and fabricated zeros would be misleading. Missing Body Battery is posted as null.
- Nudge hours are 08:00 inclusive to 21:00 exclusive, local time. Movement responses are **approximate**: a gain of at least 200 steps by the next run within 30 minutes is used as a proxy for the requested 15-minute response. Thirty-minute snapshots cannot establish which half of the interval contained those steps. Old pending nudges are consumed once and never credited after that window or across dates.
- Home demo fills only missing sensor fields. In that case it shows 18/30 minutes, 6240 steps, 7 floors and 96/150 week minutes. Valid real zero readings remain zero. A real-time five-second timer dismisses the demo banner. Seven synthetic day records are posted sequentially, marked demo, including one recovery day; this never changes the real week or gut programme storage.
- Day and demo upload responses are logged. Offline uploads can fail; background runs try a fresh current-day record again. There is no historical offline upload queue. Background work and phone connectivity are not guaranteed by the OS.
- The endpoint upserts by date, so demo and real records for a date replace one another according to the server contract.

## Verification

- `ActiveTest.mc` covers all adaptation branches, exact 80%/100% boundaries, nearest-five rounding including ties, 60/300 limits, daily ceiling/floor, recovery threshold/null, recovery floor ordering and civil week/date boundaries.
- Both requested `monkeyc` builds (normal and `-t`) are required. `-t` compiles the test program; it does **not execute** tests. Runtime Monkey C tests, visual/button checks, wake dialogs, sensor values, HTTP delivery and peak memory require a simulator/device. The simulator was deliberately not started.
- SHA-1 checks against pre-change copies verify Plan, SessionView, RatingView, SummaryView, Sensors, SensorsTest and TooShortView were not changed. Session mappings and summary keys, including omission of unread temperatures, are preserved.
