import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Demo mode replaces sensor readings with fixed, clearly labelled values so
// the flow can be shown in the simulator. Toggle it with the DOWN button.
var demoMode as Boolean = false;
const DEMO_STRESS_BEFORE = 78;
const DEMO_STRESS_AFTER = 64;

function readStress() as Number? {
    return demoMode ? DEMO_STRESS_BEFORE : Stress.current();
}

class HomeView extends WatchUi.View {

    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        var timer = new Timer.Timer();
        timer.start(method(:refresh), 5000, true);
        _timer = timer;
    }

    function onHide() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    function refresh() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var stress = readStress();
        var high = stress != null && stress >= Stress.THRESHOLD;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.17, Graphics.FONT_XTINY,
            demoMode ? "STRESS (DEMO)" : "STRESS", center);

        dc.setColor(high ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.38, Graphics.FONT_NUMBER_HOT,
            stress == null ? "--" : stress.toString(), center);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var status = "Looking calm";
        if (stress == null) {
            status = "No reading yet";
        } else if (high) {
            status = "Stress is high";
        }
        dc.drawText(cx, h * 0.60, Graphics.FONT_SMALL, status, center);

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.74, Graphics.FONT_XTINY, "START: 1-min breath", center);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY,
            "Today " + Stats.todayCount() + "  Streak " + Stats.streak(), center);
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // START button or a screen tap begins a session.
    function onSelect() as Boolean {
        WatchUi.pushView(new BreathView(readStress()), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // DOWN button toggles demo mode.
    function onNextPage() as Boolean {
        demoMode = !demoMode;
        WatchUi.requestUpdate();
        return true;
    }
}
