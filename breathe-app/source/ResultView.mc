import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Shows stress before and after the session, plus today's count and streak.
class ResultView extends WatchUi.View {

    private var _before as Number?;
    private var _after as Number?;

    function initialize(before as Number?, after as Number?) {
        View.initialize();
        _before = before;
        _after = after;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var before = _before;
        var after = _after;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.18, Graphics.FONT_SMALL, "Session done", center);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.32, Graphics.FONT_XTINY,
            demoMode ? "STRESS (DEMO)" : "STRESS", center);

        if (before != null && after != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.48, Graphics.FONT_NUMBER_MEDIUM,
                before.toString() + " - " + after.toString(), center);

            var change = after - before;
            var label = "No change yet";
            var color = Graphics.COLOR_LT_GRAY;
            if (change < 0) {
                label = "Down " + (-change).toString();
                color = Graphics.COLOR_GREEN;
            } else if (change > 0) {
                label = "Up " + change.toString();
                color = Graphics.COLOR_ORANGE;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.66, Graphics.FONT_SMALL, label, center);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.50, Graphics.FONT_SMALL, "No stress reading", center);
        }

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.82, Graphics.FONT_XTINY,
            "Today " + Stats.todayCount() + "  Streak " + Stats.streak(), center);
    }
}

class ResultDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
