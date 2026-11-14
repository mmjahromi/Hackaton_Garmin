import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class ActiveHomeView extends WatchUi.View {
    private var _record as Dictionary = {};
    private var _weekDone as Number = 0;
    private var _lastRefresh as Number = 0;
    private var _synced as Boolean = false;
    private var _timer as Timer.Timer?;
    private var _bannerTimer as Timer.Timer?;
    private var _bannerUntil as Number = 0;
    private var _demoSync as ActiveDemo;

    function initialize() {
        View.initialize();
        _demoSync = new ActiveDemo();
    }
    function onShow() as Void {
        refresh();
        if (!_synced) {
            _synced = true;
            if (ActiveData.ready(_record)) {
                try { ActiveSync.post(_record, method(:onSynced)); }
                catch (e) { System.println("Day sync could not start"); }
            }
        }
        var timer = new Timer.Timer();
        timer.start(method(:tick), 1000, true);
        _timer = timer;
    }
    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
        _timer = null;
        if (_bannerTimer != null) { _bannerTimer.stop(); }
        _bannerTimer = null;
    }
    function onSynced(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        System.println("Day sync: " + code);
    }
    private function refresh() as Void {
        _lastRefresh = System.getTimer();
        _record = ActiveData.record();
        var week = Application.Storage.getValue("activeWeek") as Dictionary;
        _weekDone = week["done"] as Number;
    }
    function tick() as Void {
        if (System.getTimer() - _lastRefresh >= 30000) { refresh(); }
        WatchUi.requestUpdate();
    }
    function demoChanged() as Void {
        _bannerUntil = demoMode ? System.getTimer() + 5000 : 0;
        if (_bannerTimer != null) { _bannerTimer.stop(); }
        _bannerTimer = null;
        if (demoMode) {
            var timer = new Timer.Timer();
            timer.start(method(:dismissBanner), 5000, false);
            _bannerTimer = timer;
            _demoSync.start();
        }
    }
    function dismissBanner() as Void {
        _bannerUntil = 0;
        _bannerTimer = null;
        WatchUi.requestUpdate();
    }
    private function shown(value as Object?) as String {
        return value == null ? "--" : value.toString();
    }
    // Fit long labels within the circular bezel using the device's text metrics.
    private function line(dc as Dc, y as Float, text as String, color as Number) as Void {
        var w = dc.getWidth();
        var font = Graphics.FONT_XTINY;
        var width = dc.getTextWidthInPixels(text, font);
        // Long recovery/START labels wrap at a space onto two centered lines.
        if (width > w * 0.80) {
            var split = text.length() / 2;
            while (split < text.length() && (text.substring(split, split + 1) as String) != " ") { split += 1; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, dc.getHeight()*y - 9, font, text.substring(0, split),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(w/2, dc.getHeight()*y + 10, font, text.substring(split + 1, text.length()),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, dc.getHeight()*y, font, text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var active = _record["activeMin"] as Number?;
        var steps = _record["steps"] as Number?;
        var floors = _record["floors"] as Number?;
        var daily = _record["dailyTarget"] as Number;
        var weekly = _record["weekTarget"] as Number;
        var done = _weekDone;
        var recovery = _record["recoveryDay"] as Boolean;
        if (demoMode) {
            // Keep real sensor readings when present; only missing values are synthetic.
            if (active == null) { active = 18; }
            if (steps == null) { steps = 6240; }
            if (floors == null) { floors = 7; }
            if (_record["activeMin"] == null) { daily = 30; weekly = 150; done = 78; recovery = false; }
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var radius = (w < h ? w : h) / 2 - 7;
        dc.setPenWidth(8);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w/2, h/2, radius);
        if (active != null && active > 0) {
            var sweep = 360 * active / daily;
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            if (sweep >= 360) { dc.drawCircle(w/2, h/2, radius); }
            else { dc.drawArc(w/2, h/2, radius, Graphics.ARC_CLOCKWISE, 90, 90-sweep); }
        }
        dc.setPenWidth(1);
        line(dc, 0.15, demoMode ? "TODAY (DEMO)" : "ACTIVE TODAY", Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*0.33, Graphics.FONT_NUMBER_MILD, shown(active),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        line(dc, 0.47, "of " + daily + " min today", Graphics.COLOR_ORANGE);
        line(dc, 0.57, shown(steps) + " steps  " + shown(floors) + " floors", Graphics.COLOR_LT_GRAY);
        line(dc, 0.69, recovery ? "Recovery day: lighter target" :
            "Week " + shown(active == null ? null : done + active) + " of " + weekly + " min", Graphics.COLOR_WHITE);
        line(dc, 0.83, "START: gut session (" + Plan.target() + " g/h)", Graphics.COLOR_LT_GRAY);
        if (demoMode && System.getTimer() < _bannerUntil) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(w*0.08, h*0.40, w*0.84, h*0.23);
            line(dc, 0.47, "Still for 52 min.", Graphics.COLOR_YELLOW);
            line(dc, 0.56, "2-minute walk?", Graphics.COLOR_YELLOW);
        }
    }
}
