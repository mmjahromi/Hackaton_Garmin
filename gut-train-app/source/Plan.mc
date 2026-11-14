import Toybox.Application;
import Toybox.Lang;

// The gut-training programme: how much carbohydrate per hour to aim for,
// and how that target moves after each session.
//
// The numbers follow general sports-nutrition guidance (start around
// 40-50 g/h, build towards 90 g/h over 6-10 weekly sessions). They are a
// starting point, not medical advice.
module Plan {

    const START_TARGET = 50;    // g/h for a first session
    const MIN_TARGET = 30;
    const MAX_TARGET = 90;
    const STEP = 10;            // g/h change after a session
    const PROGRAMME_SESSIONS = 8;
    const PORTION_G = 25;       // carbs in one feed (one gel)
    const MIN_RATED_S = 600;    // sessions shorter than this have no meaningful rate

    // Seconds between feeds so that one portion each time meets the target.
    function feedIntervalS(target as Number) as Number {
        return 3600 * PORTION_G / target;
    }

    // Carbs per hour actually eaten. Very short sessions return 0, because
    // one gel in the first minute would otherwise read as hundreds of g/h.
    function rate(carbs as Number, durationS as Number) as Number {
        if (durationS < MIN_RATED_S) {
            return 0;
        }
        return carbs * 3600 / durationS;
    }

    function target() as Number {
        var value = Application.Storage.getValue("target") as Number?;
        return (value == null) ? START_TARGET : value;
    }

    function sessionsDone() as Number {
        var value = Application.Storage.getValue("sessions") as Number?;
        return (value == null) ? 0 : value;
    }

    // Decide the next target from what the athlete actually ate and how
    // their gut felt (1 = rough, 5 = great).
    function nextTarget(target as Number, rate as Number, rating as Number) as Number {
        var hitTarget = rate * 10 >= target * 9;   // within 10% of the plan

        if (rating >= 4 && hitTarget) {
            var up = target + STEP;
            return (up > MAX_TARGET) ? MAX_TARGET : up;
        }
        if (rating <= 2) {
            var down = target - STEP;
            return (down < MIN_TARGET) ? MIN_TARGET : down;
        }
        return target;
    }

    // Start the programme again from the first session.
    function reset() as Void {
        Application.Storage.deleteValue("target");
        Application.Storage.deleteValue("sessions");
    }

    function saveSession(next as Number) as Void {
        Application.Storage.setValue("target", next);
        Application.Storage.setValue("sessions", sessionsDone() + 1);
    }
}
