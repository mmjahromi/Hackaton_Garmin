import Toybox.Lang;

// Pure rules shared by the live stress cache and its tests.
module StressPolicy {
    function validScore(value) {
        return (value instanceof Number || value instanceof Float) &&
            value >= 0 && value <= 100 && value == value.toNumber();
    }
    function valid(value, at, now) {
        return validScore(value) && at instanceof Number && at >= 0 && at <= now + 60;
    }
    function band(value) {
        if (!validScore(value)) { return null; }
        if (value <= 25) { return "resting"; }
        if (value <= 50) { return "low"; }
        if (value <= 75) { return "medium"; }
        return "high";
    }
    function shouldRefresh(nowMs, lastMs) {
        // Real monotonic milliseconds, never the accelerated workout clock.
        return lastMs == null || nowMs - lastMs >= 60000;
    }
}
