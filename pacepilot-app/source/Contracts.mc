import Toybox.Lang;
import Toybox.Math;

// Every published frame is a fresh dictionary. Null always means absence.
module Contracts {
    function reading(value, now, status) {
        return {:value=>value, :sampleMs=>now, :status=>status};
    }
    function missing(status) { return reading(null, null, status); }
    function emptyFrame(now, mode, seq) {
        return {:schemaVersion=>1, :seq=>seq, :nowMs=>now, :mode=>mode,
            :hr=>missing(:MISSING), :speed=>missing(:MISSING),
            :pressure=>missing(:MISSING), :motionRms=>missing(:MISSING),
            :gpsQuality=>:MISSING};
    }
    function copyReading(r) { return reading(r[:value], r[:sampleMs], r[:status]); }
    function numberIn(v, low, high) {
        return (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double)
            && v >= low && v <= high;
    }
    function median(values) {
        var sorted = [];
        for (var i = 0; i < values.size(); i++) {
            sorted.add(values[i]);
            var j = sorted.size() - 1;
            while (j > 0 && sorted[j] < sorted[j - 1]) {
                var swap = sorted[j - 1];
                sorted[j - 1] = sorted[j];
                sorted[j] = swap;
                j--;
            }
        }
        if (sorted.size() == 0) { return null; }
        var mid = sorted.size() / 2;
        if (sorted.size() % 2 == 0) { return (sorted[mid - 1] + sorted[mid]) / 2.0; }
        return sorted[mid];
    }
    function motionRms(x, y, z) {
        if (x == null || y == null || z == null || x.size() == 0 ||
            x.size() != y.size() || x.size() != z.size()) { return null; }
        // Welford reduction bounds memory independently of batch length.
        var mean = 0.0;
        var sum = 0.0;
        for (var i = 0; i < x.size(); i++) {
            if (!numberIn(x[i], -32000, 32000) || !numberIn(y[i], -32000, 32000) ||
                !numberIn(z[i], -32000, 32000)) { return null; }
            var radius = Math.sqrt(x[i].toFloat()*x[i] + y[i].toFloat()*y[i] + z[i].toFloat()*z[i]);
            var delta = radius - mean;
            mean += delta / (i + 1);
            sum += delta * (radius - mean);
        }
        return Math.sqrt(sum / x.size());
    }
}
