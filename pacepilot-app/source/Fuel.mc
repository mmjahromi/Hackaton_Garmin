// Fuelling inside a workout. Short sessions need no prompts, so the drink
// cue is off unless the session is long or the user turns it on.
module Fuel {
    const SIP_ML = 150;
    const PORTION_G = 25;
    const LONG_SESSION_SEC = 2700;   // 45 minutes

    // Seconds between drink cues; 0 means no cue.
    function intervalSec(mode, goalSec) {
        if (mode == 1) { return 0; }
        if (mode == 2) { return 600; }
        if (mode == 3) { return 900; }
        if (mode == 4) { return 1200; }
        return goalSec >= LONG_SESSION_SEC ? 900 : 0;
    }

    function due(sessionSec, lastDrinkSec, every) {
        return every > 0 && sessionSec - lastDrinkSec >= every;
    }

    function modeLabel(mode) {
        return ["Auto: long sessions only", "Off", "Every 10 min", "Every 15 min", "Every 20 min"][mode];
    }
}
