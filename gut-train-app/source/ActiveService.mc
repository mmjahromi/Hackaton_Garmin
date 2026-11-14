import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:background)
class ActiveService extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }

    function onTemporalEvent() as Void {
        try {
            var record = ActiveData.record();
            nudge();
            record["nudges"] = ActiveData.count("activeNudges");
            record["nudgesAnswered"] = ActiveData.count("activeAnswered");
            if (ActiveData.ready(record)) { ActiveSync.post(record, method(:onSynced)); }
            else { Background.exit(null); }
        } catch (e) {
            Background.exit(null);
        }
    }
    private function nudge() as Void {
        var now = Time.now();
        var info = ActivityMonitor.getInfo();
        var pending = Application.Storage.getValue("activePending") as Dictionary?;
        if (pending != null) {
            var elapsed = now.value() - (pending["at"] as Number);
            // Approximation: at 30-minute sampling we cannot prove that 200
            // steps happened within 15 minutes. Treat the first half-hour
            // observation as the proxy for that window; never count twice or
            // credit a later, stale run. This is NOT measured movement timing.
            if (elapsed > 0 && elapsed <= 30 * 60 && info.steps != null &&
                (info.steps as Number) - (pending["steps"] as Number) >= 200) {
                Application.Storage.setValue("activeAnswered",
                    ActiveData.bounded(ActiveData.count("activeAnswered") + 1, 100));
            }
            Application.Storage.deleteValue("activePending");
        }
        var hour = Gregorian.info(now, Time.FORMAT_SHORT).hour;
        var level = info.moveBarLevel;
        if (hour >= 8 && hour < 21 && level != null && level >= 3 &&
            ActiveData.count("activeNudges") < 100) {
            Background.requestApplicationWake("You've been still a while. 2-minute walk?");
            Application.Storage.setValue("activeNudges", ActiveData.count("activeNudges") + 1);
            if (info.steps != null) {
                Application.Storage.setValue("activePending", {"at"=>now.value(), "steps"=>info.steps});
            }
        }
    }
    function onSynced(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        Background.exit(code);
    }
}
