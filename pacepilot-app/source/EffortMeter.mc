// Average heart rate and average speed while actually moving. The dashboard
// turns these into "heartbeats per km", a simple fitness trend: as someone
// gets fitter, the same pace costs fewer beats.
//
// Only seconds with a ready heart-rate reading AND a plausible moving speed
// count, so standing still, sensor gaps and GPS glitches do not distort it.
class EffortMeter {
    const MIN_SPEED = 0.8;   // m/s, slower than this is not really moving
    const MAX_SPEED = 6.0;   // m/s, faster than this is a GPS glitch for this app
    var seconds = 0;
    var hrSum = 0.0;
    var speedSum = 0.0;
    function initialize() {}

    function add(lifecycle, features) {
        if (lifecycle != :ACTIVE || features == null || features[:hrReady] != true) { return; }
        var hr = features[:hrBpm];
        var speed = features[:speedMps];
        if (hr == null || speed == null || hr < 30 || hr > 250 || speed < MIN_SPEED || speed > MAX_SPEED) { return; }
        seconds++;
        hrSum += hr;
        speedSum += speed;
    }

    function avgHr() { return seconds > 0 ? (hrSum / seconds + 0.5).toNumber() : null; }
    // Two decimal places are plenty and keep the upload small.
    function avgSpeedMps() { return seconds > 0 ? ((speedSum / seconds) * 100 + 0.5).toNumber() / 100.0 : null; }
}
