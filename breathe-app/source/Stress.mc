import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.SensorHistory;

// Reads the watch's stress score (0-100). Shared by the app and the
// background service, so it must stay small.
(:background)
module Stress {

    // At or above this, the watch suggests a breathing session.
    const THRESHOLD = 60;

    function current() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info has :stressScore) {
            var score = info.stressScore;
            if (score != null) {
                return score;
            }
        }

        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            var it = SensorHistory.getStressHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            var sample = it.next();
            if (sample != null) {
                var data = sample.data;
                if (data != null) {
                    return data.toNumber();
                }
            }
        }
        return null;
    }
}
