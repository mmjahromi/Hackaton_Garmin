// Display bands describe the user's chosen range, not medical readiness.
module HrFeedback {
    function state(hr, ready, low, high) {
        if (!ready || hr == null) { return :UNKNOWN; }
        if (hr < low-5) { return :LOW; }
        if (hr > high+5) { return :HIGH; }
        if (hr < low || hr > high) { return :NEAR; }
        return :IN_BAND;
    }
    function color(state, now) {
        if (state == :UNKNOWN) { return 0x888888; }
        if (state == :IN_BAND) { return 0x55DD88; }
        if ((state == :HIGH || state == :LOW) && (now/1000).toNumber()%2 == 1) { return 0x554444; }
        return state == :HIGH ? 0xFF6655 : 0xFFCC55;
    }
    function message(state) {
        if (state == :UNKNOWN) { return "Check watch fit / HR"; }
        if (state == :HIGH) { return "Above band / ease effort"; }
        if (state == :LOW) { return "Below band / check effort"; }
        if (state == :NEAR) { return "Near chosen band"; }
        return "Within chosen band";
    }
}
// One cue for a sustained low-band episode; never asks the runner to speed up.
class LowBandGate {
    var since=null;
    var fired=false;
    function initialize() {}
    function update(state, now) {
        if (state != :LOW) { since=null; fired=false; return false; }
        if (since == null || now < since) { since=now; fired=false; }
        if (!fired && now-since >= 15000) { fired=true; return true; }
        return false;
    }
}
