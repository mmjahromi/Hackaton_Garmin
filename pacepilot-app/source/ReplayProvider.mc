class ReplayProvider {
    var scenario;
    var seq = 0;
    var running = false;
    function initialize(name) { scenario = name; }
    function start() { running = true; seq = 0; }
    function stop() { running = false; }
    function snapshot(nowMs) {
        var f = Contracts.emptyFrame(nowMs, :DEMO, seq);
        seq++;
        if (!running) { return f; }
        var t = nowMs / 1000;
        var hr = t < 20 || t >= 100 ? 130 : 150;
        var speed = t < 20 ? 2.5 : (t < 100 ? 2.0 : (t < 160 ? 1.2 : 2.4));
        var pressure = 100000;
        if (t >= 20) { pressure = t < 80 ? 100000 - 2 * (t - 19) : 99880; }
        f[:hr] = Contracts.reading(hr, nowMs, :VALID);
        f[:speed] = Contracts.reading(speed, nowMs, :VALID);
        f[:motionRms] = Contracts.reading(t >= 100 && t < 160 ? 100 : 150, nowMs, :VALID);
        f[:pressure] = Contracts.reading(pressure, nowMs, :VALID);
        f[:gpsQuality] = :GOOD;
        if (scenario == :LOSS && t >= 115 && t < 130) { f[:hr] = Contracts.missing(:MISSING); }
        if (scenario == :TOTAL_LOSS) { return Contracts.emptyFrame(nowMs, :DEMO, seq); }
        return f;
    }
}
