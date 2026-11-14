import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.Position;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

// The long training session. It times the next feed so the athlete hits
// today's carbs-per-hour target, and logs each feed with one button press.
//
//   START  = I just ate one portion
//   UP     = I just drank a sip
//   DOWN   = my gut is complaining (flags the moment)
//   BACK   = end the session and save it
class SessionView extends WatchUi.View {

    private const SIP_ML = 150;
    private const CARBS_FIELD_ID = 0;
    private const DEMO_FEED_S = 5;  // real seconds between feeds in demo mode

    private var _target as Number;
    private var _speed as Number;
    private var _startMs as Number = 0;
    private var _started as Boolean = false;
    private var _finished as Boolean = false;

    private var _carbs as Number = 0;
    private var _fluid as Number = 0;
    private var _lastFeedS as Number = 0;
    private var _alerted as Boolean = false;

    private var _hr as Number?;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;
    private var _maxHr as Number = 0;

    private var _gutFlags as Number = 0;
    private var _firstGutFlagS as Number = 0;

    private var _currentSpeed as Float?;
    private var _distance as Float?;
    private var _ascent as Number = 0;
    private var _temp as Float?;
    private var _tempSum as Float = 0.0;
    private var _tempCount as Number = 0;
    private var _maxTemp as Float?;
    private var _cadenceSum as Number = 0;
    private var _cadenceCount as Number = 0;
    private var _previousMagnitude as Float?;
    private var _stopStartMs as Number?;
    private var _stopCounted as Boolean = false;
    private var _stops as Number = 0;
    private var _stoppedMs as Number = 0;
    private var _demoStopMs as Number?;
    private var _hardFeeds as Number = 0;
    private var _userMaxHr as Number = 0;
    private var _lastDrinkS as Number = 0;
    private var _drinkDue as Boolean = false;
    private var _hotDrinkPrompts as Number = 0;
    private var _sensorsActive as Boolean = false;

    private var _timer as Timer.Timer?;
    private var _recording as ActivityRecording.Session?;
    private var _carbsField as FitContributor.Field?;

    function initialize(target as Number) {
        View.initialize();
        _target = target;
        // In demo mode the clock is sped up so each feed comes round in 5 seconds.
        _speed = demoMode ? intervalS() / DEMO_FEED_S : 1;
    }

    function onShow() as Void {
        if (!_started) {
            _started = true;
            _startMs = System.getTimer();
            _userMaxHr = profileMaxHr();
            if (demoMode && _userMaxHr == 0) { _userMaxHr = 185; }
            startRecording();
        }
        startSensors();
        var timer = new Timer.Timer();
        timer.start(method(:tick), 500, true);
        _timer = timer;
    }

    function onHide() as Void {
        stopTimer();
        stopSensors();
        closeStop(System.getTimer());
        _previousMagnitude = null;
    }

    private function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    // Record a real activity so the session (and the carbs eaten) lands in
    // Garmin Connect alongside heart rate and GPS.
    private function startRecording() as Void {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }
        var recording = ActivityRecording.createSession({
            :name => "Gut Training",
            :sport => Activity.SPORT_CYCLING
        });
        _carbsField = recording.createField("carbs_eaten", CARBS_FIELD_ID,
            FitContributor.DATA_TYPE_UINT16,
            { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "g" });
        recording.start();
        _recording = recording;
    }

    // Session seconds. In demo mode the clock runs much faster than real time.
    function elapsedS() as Number {
        return ((System.getTimer() - _startMs) * _speed) / 1000;
    }

    // Seconds between feeds so that one portion each time meets the target.
    private function intervalS() as Number {
        return Plan.feedIntervalS(_target);
    }

    private function dueInS() as Number {
        return _lastFeedS + intervalS() - elapsedS();
    }

    private function plannedSoFar() as Number {
        return _target * elapsedS() / 3600;
    }

    private function buzz(ms as Number) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(75, ms)]);
        }
    }

    function tick() as Void {
        if (_finished) {
            return;
        }
        sampleSensors();
        var sinceDrink = elapsedS() - _lastDrinkS;
        if (!_drinkDue && sinceDrink >= Sensors.drinkIntervalS(_temp)) {
            _drinkDue = true;
            if (Sensors.drinkIntervalS(_temp) == 600 && sinceDrink < 900) {
                _hotDrinkPrompts += 1;
            }
            buzz(300);
        }
        if (dueInS() <= 0 && !_alerted) {
            _alerted = true;
            buzz(600);
        }
        WatchUi.requestUpdate();
    }

    private function startSensors() as Void {
        if (_sensorsActive) { return; }
        _sensorsActive = true;
        // Sensor APIs: 1.0; accelerometer listener: 2.3. Enable alongside
        // ActivityRecording; polling Info avoids a second sensor-event stream.
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE,
                Sensor.SENSOR_TEMPERATURE, Sensor.SENSOR_BIKECADENCE]);
        }
        if (Sensor has :registerSensorDataListener) {
            Sensor.registerSensorDataListener(method(:onAccel), {
                :period => 1, :accelerometer => { :enabled => true, :sampleRate => 25 }
            });
        }
        // Recording alone is not a request for continuous GPS acquisition.
        // Positioning permission and this API (1.0) supply Activity.Info GPS.
        if (Position has :enableLocationEvents) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function onAccel(data as Sensor.SensorData) as Void {
        // Registration activates accel; sampleSensors reads Sensor.Info.accel.
    }

    function onPosition(info as Position.Info) as Void {
        // Activity.Info supplies speed and the recording's accumulated distance.
    }

    private function stopSensors() as Void {
        if (!_sensorsActive) { return; }
        if (Sensor has :unregisterSensorDataListener) { Sensor.unregisterSensorDataListener(); }
        if (Sensor has :setEnabledSensors) { Sensor.setEnabledSensors([]); }
        if (Position has :enableLocationEvents) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        }
        _sensorsActive = false;
    }

    private function closeStop(now as Number) as Void {
        var start = _stopStartMs;
        if (start != null && _stopCounted) {
            var end = now;
            var demoStart = _demoStopMs;
            if (demoMode && demoStart != null && end > demoStart + 6000) {
                end = demoStart + 6000;
            }
            _stoppedMs += end - start;
        }
        _stopStartMs = null;
        _stopCounted = false;
    }

    private function readActivity() as Void {
        var info = Activity.getActivityInfo();
        _hr = null;
        _currentSpeed = null;
        if (info == null) { return; }
        readHeartRate(info);
        readSpeed(info);
        readDistance(info);
        readAscent(info);
        readCadence(info);
    }

    private function readHeartRate(info as Activity.Info) as Void {
        if (info has :currentHeartRate) { _hr = info.currentHeartRate; }
        if (_hr == null && demoMode) { _hr = 138; }
        var hr = _hr;
        if (hr == null || hr <= 0) { return; }
        _hrSum += hr;
        _hrCount += 1;
        if (hr > _maxHr) { _maxHr = hr; }
    }

    private function readSpeed(info as Activity.Info) as Void {
        if (info has :currentSpeed) { _currentSpeed = info.currentSpeed; }
        if (_currentSpeed == null && demoMode) { _currentSpeed = 8.0; }
    }

    private function readDistance(info as Activity.Info) as Void {
        var value = null as Float?;
        if (info has :elapsedDistance) { value = info.elapsedDistance; }
        if (value == null && demoMode) { value = 8.0 * elapsedS(); }
        if (value != null) { _distance = value; }
    }

    private function readAscent(info as Activity.Info) as Void {
        var value = null as Number?;
        if (info has :totalAscent) { value = info.totalAscent; }
        if (value == null && demoMode) { value = elapsedS() * 400 / 3600; }
        if (value != null) { _ascent = value; }
    }

    private function readCadence(info as Activity.Info) as Void {
        var value = null as Number?;
        if (info has :currentCadence) { value = info.currentCadence; }
        if (value == null && demoMode) { value = 88; }
        if (value == null || value < 0) { return; }
        _cadenceSum += value;
        _cadenceCount += 1;
    }

    private function readTemperature(sensor as Sensor.Info) as Void {
        if (sensor has :temperature) { _temp = sensor.temperature; }
    }

    private function recordTemperature() as Void {
        if (_temp == null && demoMode) { _temp = 28.0; }
        var temp = _temp;
        if (temp == null) { return; }
        _tempSum += temp;
        _tempCount += 1;
        if (_maxTemp == null || temp > _maxTemp) { _maxTemp = temp; }
    }

    private function acceleration(sensor as Sensor.Info) as Float? {
        if (!(sensor has :accel)) { return null; }
        var accel = sensor.accel;
        if (accel == null || accel.size() < 3) { return null; }
        var x = accel[0].toFloat();
        var y = accel[1].toFloat();
        var z = accel[2].toFloat();
        return Math.sqrt(x*x + y*y + z*z).toFloat();
    }

    private function sampleSensors() as Void {
        readActivity();
        _temp = null;
        var magnitude = null as Float?;
        if (Sensor has :getInfo) {
            var sensor = Sensor.getInfo();
            if (sensor != null) {
                readTemperature(sensor);
                magnitude = acceleration(sensor);
            }
        }
        recordTemperature();
        updateMotion(magnitude);
    }

    private function updateMotion(magnitude as Float?) as Void {
        var motion = null as Float?;
        var previous = _previousMagnitude;
        if (magnitude != null && previous != null) { motion = (magnitude - previous).abs(); }
        _previousMagnitude = magnitude;
        var stopped = Sensors.isStopped(_currentSpeed, motion);
        var now = System.getTimer();
        var demoStart = _demoStopMs;
        if (demoMode) {
            // Exactly one synthetic stop, even when live sensors are present.
            stopped = demoStart != null && now - demoStart < 6000;
        }
        updateStop(stopped, now);
    }

    private function updateStop(stopped as Boolean, now as Number) as Void {
        if (!stopped) { closeStop(now); return; }
        if (_stopStartMs == null) { _stopStartMs = now; }
        var start = _stopStartMs;
        if (start != null && !_stopCounted && Sensors.stopQualified(now - start, demoMode)) {
            _stopCounted = true;
            _stops += 1;
        }
    }

    function logFeed() as Void {
        if (Sensors.hardFeed(_hr, _userMaxHr)) { _hardFeeds += 1; }
        _carbs += Plan.PORTION_G;
        if (demoMode && _carbs == 3 * Plan.PORTION_G) {
            closeStop(System.getTimer());
            _demoStopMs = System.getTimer();
            _stopStartMs = _demoStopMs;
        }
        _lastFeedS = elapsedS();
        _alerted = false;
        buzz(150);
        WatchUi.requestUpdate();
    }

    function logDrink() as Void {
        _fluid += SIP_ML;
        _lastDrinkS = elapsedS();
        _drinkDue = false;
        buzz(80);
        WatchUi.requestUpdate();
    }

    // Marks the moment the gut started to complain, so the dashboard can
    // show how far into a session trouble tends to begin.
    function logGutFlag() as Void {
        if (_gutFlags == 0) {
            _firstGutFlagS = elapsedS();
        }
        _gutFlags += 1;
        buzz(80);
        WatchUi.requestUpdate();
    }

    // The athlete's maximum heart rate from their Garmin profile (the top
    // of zone 5), or 0 when the profile has none.
    private function profileMaxHr() as Number {
        if (!(UserProfile has :getHeartRateZones)) { return 0; }
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones != null && zones.size() > 5) {
            return zones[5];
        }
        return 0;
    }

    function finish() as Void {
        if (_finished) {
            return;
        }
        sampleSensors();
        closeStop(System.getTimer());
        stopSensors();
        _finished = true;
        stopTimer();

        var durationS = elapsedS();
        // A session under ten minutes says nothing about the gut, so it must
        // not change the programme, be rated, or be saved anywhere.
        var tooShort = durationS < Plan.MIN_RATED_S;

        var calories = 0;
        var caloriesKnown = false;
        var info = Activity.getActivityInfo();
        if (info != null && info has :calories) {
            var burned = info.calories;
            if (burned != null) {
                calories = burned;
                caloriesKnown = true;
            }
        }


        var recording = _recording;
        if (recording != null) {
            var field = _carbsField;
            if (field != null) {
                field.setData(_carbs);
            }
            recording.stop();
            // Demo sessions are fake, so keep them out of the activity history.
            if (demoMode || tooShort) {
                recording.discard();
            } else {
                recording.save();
            }
        }

        if (tooShort) {
            System.println("Session too short to count: " + durationS + " s");
            WatchUi.switchToView(new TooShortView(_target), new SummaryDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }

        var avgHr = (_hrCount > 0) ? _hrSum / _hrCount : 0;
        var maxHr = _maxHr;
        var userMaxHr = _userMaxHr;

        // A demo session lasts seconds, so the sensors have nothing real to
        // report. Fill in typical long-ride values; the session is flagged
        // as a demo everywhere it is shown.
        if (demoMode) {
            if (_hrCount == 0) { avgHr = 138; maxHr = 152; }
            if (!caloriesKnown) { calories = durationS * 650 / 3600; }
        }

        var rate = Plan.rate(_carbs, durationS);
        var summary = {
            "durationS" => durationS,
            "carbsG" => _carbs,
            "fluidMl" => _fluid,
            "targetGph" => _target,
            "rateGph" => rate,
            "avgHr" => avgHr,
            "maxHr" => maxHr,
            "userMaxHr" => userMaxHr,
            "calories" => calories,
            "gutEvents" => _gutFlags,
            "firstGutEventS" => _firstGutFlagS,
            "demo" => demoMode
        };
        addSensorSummary(summary);
        System.println("Session ended: " + summary);

        var rating = new RatingView();
        WatchUi.switchToView(rating, new RatingDelegate(rating, summary), WatchUi.SLIDE_LEFT);
    }

    private function addSensorSummary(summary as Dictionary) as Void {
        summary["distanceM"] = Sensors.bounded(whole(_distance), 0, 500000);
        summary["ascentM"] = Sensors.bounded(_ascent, 0, 20000);
        // 0 °C is a real reading, so a missing temperature is left out
        // rather than sent as 0.
        if (_tempCount > 0) {
            summary["avgTempC"] = Sensors.bounded(average(_tempSum, _tempCount), -40, 60);
            summary["maxTempC"] = Sensors.bounded(whole(_maxTemp), -40, 60);
        }
        summary["stops"] = Sensors.bounded(_stops, 0, 500);
        summary["stoppedS"] = Sensors.bounded((_stoppedMs.toFloat() * _speed / 1000).toNumber(), 0, 86400);
        summary["hardFeeds"] = Sensors.bounded(_hardFeeds, 0, 200);
        summary["avgCadence"] = Sensors.bounded(average(_cadenceSum.toFloat(), _cadenceCount), 0, 250);
        summary["hotDrinkPrompts"] = Sensors.bounded(_hotDrinkPrompts, 0, 500);
    }

    private function whole(value as Float?) as Number {
        return value == null ? 0 : value.toNumber();
    }

    private function average(sum as Float, count as Number) as Number {
        return count == 0 ? 0 : (sum / count).toNumber();
    }

    private function clock(totalS as Number) as String {
        if (totalS < 0) {
            totalS = 0;
        }
        var hours = totalS / 3600;
        var minutes = (totalS % 3600) / 60;
        var seconds = totalS % 60;
        if (hours > 0) {
            return hours + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
        }
        return minutes + ":" + seconds.format("%02d");
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cy = h / 2;
        var dueIn = dueInS();
        var due = dueIn <= 0;

        // Ring round the edge: drains as the next feed approaches, then
        // turns solid orange when it is time to eat.
        var ringR = (w < h ? w : h) / 2 - 7;
        dc.setPenWidth(8);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, ringR);
        if (due) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, ringR);
        } else {
            var sweep = 360 * dueIn / intervalS();
            if (sweep >= 360) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(cx, cy, ringR);
            } else if (sweep > 0) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, ringR, Graphics.ARC_CLOCKWISE, 90, 90 - sweep);
            }
        }
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.14, Graphics.FONT_XTINY,
            clock(elapsedS()) + (demoMode ? " DEMO" : "") +
                (_gutFlags > 0 ? " G" + _gutFlags : ""), center);

        if (due) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.26, Graphics.FONT_XTINY,
                Sensors.hardFeed(_hr, _userMaxHr) ? "Ease off, then eat" : "FUEL NOW", center);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.37, Graphics.FONT_XTINY, Plan.PORTION_G + " g, then press START", center);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.24, Graphics.FONT_XTINY, _drinkDue ? "DRINK" : "NEXT FUEL", center);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.36, Graphics.FONT_NUMBER_MILD, clock(dueIn), center);
        }

        // Split the stop message over two short lines inside the round bezel.
        if (_stopCounted) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.47, Graphics.FONT_XTINY, "Stopped. DOWN", center);
            dc.drawText(cx, h * 0.55, Graphics.FONT_XTINY, "if it's your gut.", center);
        }

        // Carbs eaten against the plan so far: the one number that matters.
        var planned = plannedSoFar();
        var onPlan = _carbs * 10 >= planned * 9;
        var barW = (w * 0.46).toNumber();
        var barH = 8;
        var barX = cx - barW / 2;
        var barY = (h * 0.62).toNumber();
        var filled = barW;
        if (planned > 0 && _carbs < planned) {
            filled = barW * _carbs / planned;
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 4);
        if (filled > 0) {
            dc.setColor(onPlan ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barY, filled, barH, 4);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.71, Graphics.FONT_SMALL, _carbs + " of " + planned + " g", center);

        drawFooter(dc);
    }
    private function drawFooter(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var hr = _hr;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.80, Graphics.FONT_XTINY,
            (hr == null ? "--" : hr.toString()) + " bpm   " + _fluid + " ml", center);
        var details = "";
        var distance = _distance;
        var temp = _temp;
        if (distance != null) { details = (distance / 1000.0).format("%.1f") + " km"; }
        if (temp != null) { details += "  " + temp.format("%.0f") + "°C"; }
        dc.drawText(cx, h * 0.88, Graphics.FONT_XTINY, details, center);
    }

}

class SessionDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SessionView;

    function initialize(view as SessionView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.logFeed();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.logDrink();
        return true;
    }

    function onNextPage() as Boolean {
        _view.logGutFlag();
        return true;
    }

    function onBack() as Boolean {
        _view.finish();
        return true;
    }
}
