import Toybox.Lang;
import Toybox.Test;

(:test)
function stopNeedsSpeedAndMotion(logger as Logger) as Boolean {
    return Sensors.isStopped(0.0, 0.0) && Sensors.isStopped(0.49, 49.0) &&
        !Sensors.isStopped(0.5, 0.0) && !Sensors.isStopped(0.0, 50.0) &&
        !Sensors.isStopped(null, 0.0) && !Sensors.isStopped(0.0, null);
}

(:test)
function stopUsesRealTime(logger as Logger) as Boolean {
    return !Sensors.stopQualified(59999, false) && Sensors.stopQualified(60000, false) &&
        !Sensors.stopQualified(4999, true) && Sensors.stopQualified(5000, true);
}

(:test)
function heatShortensDrinkInterval(logger as Logger) as Boolean {
    return Sensors.drinkIntervalS(null) == 900 && Sensors.drinkIntervalS(26.9) == 900 &&
        Sensors.drinkIntervalS(27.0) == 600 && Sensors.drinkIntervalS(28.0) == 600;
}

(:test)
function hardFeedNeedsKnownHrAboveThreshold(logger as Logger) as Boolean {
    return !Sensors.hardFeed(null, 200) && !Sensors.hardFeed(180, 0) &&
        !Sensors.hardFeed(170, 200) && Sensors.hardFeed(171, 200);
}

(:test)
function contractBoundsPreserveSignedTemperature(logger as Logger) as Boolean {
    return Sensors.bounded(-12, -40, 60) == -12 &&
        Sensors.bounded(600000, 0, 500000) == 500000 && Sensors.bounded(-1, 0, 500) == 0;
}
