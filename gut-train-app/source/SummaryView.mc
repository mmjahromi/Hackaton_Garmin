import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Where finished sessions are sent. Leave empty to keep everything on the
// watch. Must be an https address; the request travels through the phone.
const SYNC_URL = "https://gut-train-web.vercel.app/api/sessions";

// Shows what was eaten against the target, the gut rating and the target
// for next time, then sends the session to the web dashboard.
class SummaryView extends WatchUi.View {

    private var _summary as Dictionary;
    private var _gutLabel as String;
    private var _syncStatus as String = "Saved on watch";

    function initialize(summary as Dictionary, gutLabel as String) {
        View.initialize();
        _summary = summary;
        _gutLabel = gutLabel;
        _syncStatus = summary.hasKey("localSaved") && summary["localSaved"] == true ? "Saved on watch" : "Local save failed";
        if (demoMode) { _syncStatus = "Demo / not saved"; }
        if (nutritionShare && !demoMode) { sync(); }
    }

    private function sync() as Void {
        if (SYNC_URL.length() == 0) {
            return;
        }
        _syncStatus = "Syncing...";
        try { Communications.makeWebRequest(
            SYNC_URL,
            _summary as Dictionary<Object, Object>,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onSynced)); }
        catch (e) { _syncStatus = "Share failed"; }
    }

    function onSynced(code as Number, data as Dictionary or String or Null) as Void {
        System.println("Sync response: " + code);
        _syncStatus = (code == 200 || code == 201) ? "Synced" : "Sync failed (" + code + ")";
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var target = _summary["targetGph"] as Number;
        var rate = _summary["rateGph"] as Number;
        var rating = _summary["gutRating"] as Number;
        var next = _summary["nextTargetGph"] as Number;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.14, Graphics.FONT_XTINY,
            demoMode ? "SESSION DONE (DEMO)" : "SESSION DONE", center);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.29, Graphics.FONT_MEDIUM, rate + " of " + target + " g/h", center);
        dc.drawText(cx, h * 0.44, Graphics.FONT_SMALL, "Gut: " + _gutLabel + " (" + rating + "/5)", center);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.58, Graphics.FONT_XTINY, "YOUR CONFIRMED PLAN", center);

        var color = Graphics.COLOR_YELLOW;
        if (next > target) {
            color = Graphics.COLOR_GREEN;
        } else if (next < target) {
            color = Graphics.COLOR_ORANGE;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.71, Graphics.FONT_MEDIUM, next + " g/h", center);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY, _syncStatus, center);
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
