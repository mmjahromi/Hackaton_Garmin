import Toybox.Sensor;
import Toybox.Position;
import Toybox.System;

class LiveProvider {
    var frame;
    var origin;
    var seq = 0;
    var running = false;
    var sensorOwned = false;
    var accelOwned = false;
    var positionOwned = false;
    var lastFix = null;
    var onboard = false;
    function initialize() { frame = Contracts.emptyFrame(0, :LIVE, 0); }
    function now() { return System.getTimer() - origin; }
    function start() {
        if (running) { return; }
        origin = System.getTimer(); seq = 0; lastFix = null;
        frame = Contracts.emptyFrame(0, :LIVE, 0);
        running = true;
        try {
            if (Sensor has :SENSOR_ONBOARD_HEARTRATE) {
                var enabled = Sensor.setEnabledSensors([Sensor.SENSOR_ONBOARD_HEARTRATE]);
                onboard = enabled != null && enabled.indexOf(Sensor.SENSOR_ONBOARD_HEARTRATE) != -1;
            }
            if (!onboard) { frame[:hr] = Contracts.missing(:UNSUPPORTED); }
            Sensor.enableSensorEvents(method(:onSensor));
            sensorOwned = true;
        } catch (e) { frame[:hr] = Contracts.missing(:ERROR); frame[:pressure] = Contracts.missing(:ERROR); }
        try {
            if (Sensor has :registerSensorDataListener) {
                Sensor.registerSensorDataListener(method(:onMotion),
                    {:period=>1, :accelerometer=>{:enabled=>true, :sampleRate=>25}});
                accelOwned = true;
            } else { frame[:motionRms] = Contracts.missing(:UNSUPPORTED); }
        } catch (e) { frame[:motionRms] = Contracts.missing(:ERROR); }
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            positionOwned = true;
        } catch (e) { frame[:speed] = Contracts.missing(:ERROR); }
    }
    function onSensor(info as Sensor.Info) as Void {
        if (!running) { return; }
        if (onboard) { frame[:hr] = Contracts.reading(info.heartRate, now(), info.heartRate == null ? :MISSING : :VALID); }
        if (info has :pressure) {
            frame[:pressure] = Contracts.reading(info.pressure, now(), info.pressure == null ? :MISSING : :VALID);
        } else { frame[:pressure] = Contracts.missing(:UNSUPPORTED); }
    }
    function onMotion(data as Sensor.SensorData) as Void {
        if (!running) { return; }
        var a = data.accelerometerData;
        var rms = a == null ? null : Contracts.motionRms(a.x, a.y, a.z);
        frame[:motionRms] = Contracts.reading(rms, now(), rms == null ? :MISSING : :VALID);
    }
    function onPosition(info as Position.Info) as Void {
        if (!running) { return; }
        var quality = info.accuracy;
        frame[:gpsQuality] = quality == Position.QUALITY_GOOD ? :GOOD :
            (quality == Position.QUALITY_USABLE ? :USABLE : :MISSING);
        if (info.speed == null || frame[:gpsQuality] == :MISSING) {
            frame[:speed] = Contracts.missing(:MISSING);
            return;
        }
        var fix = info.when == null ? null : info.when.value();
        if (fix != null && lastFix != null && fix <= lastFix) { return; }
        lastFix = fix;
        frame[:speed] = Contracts.reading(info.speed, now(), :VALID);
    }
    function snapshot(nowMs) {
        var result = Contracts.emptyFrame(nowMs, :LIVE, seq);
        seq++;
        var channels = [:hr, :speed, :pressure, :motionRms];
        for (var i = 0; i < channels.size(); i++) {
            result[channels[i]] = Contracts.copyReading(frame[channels[i]]);
        }
        result[:gpsQuality] = frame[:gpsQuality];
        return result;
    }
    function stop() {
        running = false;
        if (sensorOwned) {
            try { Sensor.enableSensorEvents(null); Sensor.setEnabledSensors([]); } catch (e) {}
            sensorOwned = false;
        }
        if (accelOwned) {
            try { Sensor.unregisterSensorDataListener(); } catch (e) {}
            accelOwned = false;
        }
        if (positionOwned) {
            try { Position.enableLocationEvents(Position.LOCATION_DISABLE, null); } catch (e) {}
            positionOwned = false;
        }
    }
}
