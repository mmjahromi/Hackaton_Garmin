import Toybox.Lang;

// Each channel consumes a timestamp once. Cached snapshots never add samples.
class SampleWindow {
    var samples;
    var lastSample;
    var status;
    var maxAge;
    var minimum;
    var maximum;
    var capacity;
    function initialize(age, low, high, cap) {
        maxAge = age; minimum = low; maximum = high; capacity = cap;
        reset();
    }
    function reset() { samples = []; lastSample = null; status = :MISSING; }
    function update(reading, now) {
        status = reading[:status];
        var stamp = reading[:sampleMs];
        var value = reading[:value];
        if (status == :VALID && !Contracts.numberIn(value, minimum, maximum)) { status = :MISSING; }
        if (status == :VALID && (stamp == null || stamp > now)) { status = :MISSING; }
        if (status == :VALID && now - stamp > maxAge) { status = :STALE; }
        if (status != :VALID) { samples = []; lastSample = null; return null; }
        if (lastSample != null && stamp < lastSample) {
            status = :STALE; samples = []; lastSample = null; return null;
        }
        if (lastSample == null || stamp > lastSample) {
            samples.add([stamp, value]);
            lastSample = stamp;
        }
        var kept = [];
        for (var i = 0; i < samples.size(); i++) {
            if (now - samples[i][0] <= maxAge) { kept.add(samples[i]); }
        }
        while (kept.size() > capacity) { kept = kept.slice(1, kept.size()); }
        samples = kept;
        var values = [];
        for (var j = 0; j < samples.size(); j++) { values.add(samples[j][1]); }
        return Contracts.median(values);
    }
}

class MotionVote {
    var vote = :UNKNOWN;
    var highSec = 0.0;
    var lowSec = 0.0;
    function reset() { vote = :UNKNOWN; highSec = 0.0; lowSec = 0.0; }
    function update(value, dt, high, low) {
        if (value == null) { reset(); return vote; }
        highSec = value >= high ? highSec + dt : 0.0;
        lowSec = value <= low ? lowSec + dt : 0.0;
        if (highSec >= 3) { vote = :MOVING; }
        if (lowSec >= 10) { vote = :STILL; }
        return vote;
    }
}

class FeaturePipeline {
    var hr;
    var speed;
    var motion;
    var pressure;
    var accelVote;
    var gpsVote;
    var previousNow;
    var afterMs = null;
    var hrSince;
    var terrainSamples;
    var pressureStamp;
    var candidate;
    var candidateSince;
    var config;
    function initialize(c) {
        config = c;
        hr = new SampleWindow(5000, 30, 240, 5);
        speed = new SampleWindow(5000, 0, 12, 3);
        motion = new SampleWindow(3000, 0, 32000, 1);
        pressure = new SampleWindow(10000, 30000, 110000, 1);
        accelVote = new MotionVote();
        gpsVote = new MotionVote();
        reset();
    }
    function reset() {
        hr.reset(); speed.reset(); motion.reset(); pressure.reset();
        accelVote.reset(); gpsVote.reset();
        previousNow = null; hrSince = null; afterMs = null;
        clearTerrain();
    }
    function resetAfter(now) { reset(); afterMs = now; }
    function eligible(reading) {
        if (afterMs != null && reading[:sampleMs] != null && reading[:sampleMs] <= afterMs) {
            return Contracts.missing(:MISSING);
        }
        return reading;
    }
    function clearTerrain() {
        terrainSamples = []; pressureStamp = null;
        candidate = :UNKNOWN; candidateSince = null;
    }
    function terrain(p, movement, now) {
        if (p == null || movement != :MOVING) { clearTerrain(); return :UNKNOWN; }
        var stamp = pressure.lastSample;
        if (pressureStamp == null || stamp > pressureStamp) {
            if (pressureStamp != null && stamp - pressureStamp > 3000) { clearTerrain(); }
            terrainSamples.add([stamp, p]);
            pressureStamp = stamp;
        }
        var kept = [];
        for (var i = 0; i < terrainSamples.size(); i++) {
            if (now - terrainSamples[i][0] <= 35000) { kept.add(terrainSamples[i]); }
        }
        while (kept.size() > 40) { kept = kept.slice(1, kept.size()); }
        terrainSamples = kept;
        var next = :UNKNOWN;
        var n = kept.size();
        if (n >= 25 && kept[n-1][0] - kept[0][0] >= 30000) {
            var first = [];
            var last = [];
            for (var k = 0; k < 5; k++) { first.add(kept[k][1]); last.add(kept[n-5+k][1]); }
            var delta = Contracts.median(last) - Contracts.median(first);
            if (delta <= -40) { next = :UP; }
            else if (delta >= 40) { next = :DOWN; }
            else if (delta > -20 && delta < 20) { next = :FLAT; }
        }
        if (next != candidate) { candidate = next; candidateSince = now; }
        if (next == :UNKNOWN || candidateSince == null || now - candidateSince < 10000) { return :UNKNOWN; }
        return next;
    }
    function update(frame, now) {
        var dt = previousNow == null ? 0.0 : (now - previousNow) / 1000.0;
        if (dt < 0 || dt > 2) { reset(); dt = 0.0; }
        previousNow = now;
        var bpm = hr.update(eligible(frame[:hr]), now);
        if (hr.status != :VALID) { hrSince = null; }
        else if (hrSince == null) { hrSince = now; }
        if (hr.samples.size() < 3) { bpm = null; }
        var speedReading = eligible(frame[:speed]);
        if (speedReading[:status] == :VALID && frame[:gpsQuality] != :GOOD && frame[:gpsQuality] != :USABLE) {
            speedReading = Contracts.missing(:MISSING);
        }
        var mps = speed.update(speedReading, now);
        var rms = motion.update(eligible(frame[:motionRms]), now);
        var p = pressure.update(eligible(frame[:pressure]), now);
        var av = accelVote.update(rms, dt, 80, 40);
        var gv = gpsVote.update(mps, dt, 0.8, 0.3);
        var movement = :UNKNOWN;
        if (av == :MOVING || gv == :MOVING) { movement = :MOVING; }
        else if ((rms == null || av == :STILL) && (mps == null || gv == :STILL) &&
            (av == :STILL || gv == :STILL)) { movement = :STILL; }
        return {:nowMs=>now, :hrBpm=>bpm,
            :hrReady=>bpm != null && hrSince != null && now - hrSince >= config[:hrReacquireSec]*1000,
            :speedMps=>mps, :movement=>movement, :terrain=>terrain(p, movement, now),
            :sourceStatus=>{:hr=>hr.status, :speed=>speed.status, :motionRms=>motion.status, :pressure=>pressure.status},
            :mode=>frame[:mode]};
    }
}
