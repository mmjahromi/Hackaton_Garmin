import Toybox.Lang;

// Pure sensor decisions: missing data never means stationary or hard effort.
module Sensors {
    function isStopped(speed as Float?, motion as Float?) as Boolean {
        // Acceleration is in millig; tolerate small wrist/sensor noise.
        if (speed == null) { return false; }
        if (motion == null) { return false; }
        if (speed < 0 || speed >= 0.5) { return false; }
        return motion >= 0 && motion < 50.0;
    }

    function stopQualified(realMs as Number, demo as Boolean) as Boolean {
        return realMs >= (demo ? 5000 : 60000);
    }

    function drinkIntervalS(temp as Float?) as Number {
        // A wrist thermometer reads warmer than air because of body heat;
        // use 27 C as the reminder threshold, not an ambient heat diagnosis.
        if (temp == null) { return 900; }
        return temp >= 27.0 ? 600 : 900;
    }

    function hardFeed(hr as Number?, maxHr as Number) as Boolean {
        if (hr == null) { return false; }
        if (hr <= 0 || maxHr <= 0) { return false; }
        return hr * 100 > maxHr * 85;
    }

    function bounded(value as Number, low as Number, high as Number) as Number {
        return value < low ? low : (value > high ? high : value);
    }
}
