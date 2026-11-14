import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// One-minute guided session: 6 cycles of 4 s in, 6 s out. A longer exhale
// than inhale is the usual pattern for calming down. In demo mode it is a
// single 5-second breath (2 s in, 3 s out) so it can be shown quickly.
class BreathView extends WatchUi.View {

    private var INHALE_MS as Number = 4000;
    private var EXHALE_MS as Number = 6000;
    private var CYCLES as Number = 6;

    private var _before as Number?;
    private var _startMs as Number = 0;
    private var _timer as Timer.Timer?;
    private var _inhaling as Boolean = true;
    private var _done as Boolean = false;

    function initialize(before as Number?) {
        View.initialize();
        _before = before;
        if (demoMode) {
            INHALE_MS = 2000;
            EXHALE_MS = 3000;
            CYCLES = 1;
        }
    }

    function onShow() as Void {
        _startMs = System.getTimer();
        _inhaling = true;
        _done = false;
        buzz();
        var timer = new Timer.Timer();
        timer.start(method(:tick), 100, true);
        _timer = timer;
    }

    function onHide() as Void {
        stopTimer();
    }

    private function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _timer = null;
    }

    private function buzz() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }
    }

    function tick() as Void {
        if (_done) {
            return;
        }
        var elapsed = System.getTimer() - _startMs;
        var cycleMs = INHALE_MS + EXHALE_MS;

        if (elapsed >= cycleMs * CYCLES) {
            finish();
            return;
        }

        var inhaling = (elapsed % cycleMs) < INHALE_MS;
        if (inhaling != _inhaling) {
            _inhaling = inhaling;
            buzz();
        }
        WatchUi.requestUpdate();
    }

    private function finish() as Void {
        _done = true;
        stopTimer();
        buzz();
        Stats.record();

        var after = demoMode ? DEMO_STRESS_AFTER : Stress.current();
        System.println("Session done, stress " + _before + " -> " + after);
        WatchUi.switchToView(new ResultView(_before, after), new ResultDelegate(), WatchUi.SLIDE_LEFT);
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var cycleMs = INHALE_MS + EXHALE_MS;
        var totalMs = cycleMs * CYCLES;
        var elapsed = System.getTimer() - _startMs;
        if (elapsed > totalMs) {
            elapsed = totalMs;
        }
        var inCycle = elapsed % cycleMs;

        // 0.0 = lungs empty, 1.0 = lungs full.
        var fill = 0.0;
        if (inCycle < INHALE_MS) {
            fill = inCycle.toFloat() / INHALE_MS;
        } else {
            fill = 1.0 - (inCycle - INHALE_MS).toFloat() / EXHALE_MS;
        }
        // Ease in and out so the circle slows at each end.
        fill = fill * fill * (3.0 - 2.0 * fill);

        var maxR = (w < h ? w : h) * 0.36;
        var minR = maxR * 0.35;
        var r = (minR + (maxR - minR) * fill).toNumber();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, maxR.toNumber());

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL,
            inCycle < INHALE_MS ? "Breathe in" : "Breathe out", center);

        var secondsLeft = (totalMs - elapsed + 999) / 1000;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.93, Graphics.FONT_XTINY, secondsLeft.toString() + "s", center);
    }
}
