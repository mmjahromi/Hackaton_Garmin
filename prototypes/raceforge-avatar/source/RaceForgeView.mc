import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class RaceForgeView extends WatchUi.View {
    private var _demo as RaceForgeAvatarDemoController;
    private var _renderer as RaceForgeAvatarRenderer;
    private var _timer as Timer.Timer;
    private var _visible as Boolean = false;
    private var _timerRunning as Boolean = false;
    private var _lastNow as Number = 0;
    private var _surface as Graphics.BufferedBitmap? = null;

    function initialize() {
        View.initialize();
        _demo = new RaceForgeAvatarDemoController();
        _demo.setMode(:EASY_RUN);
        _renderer = new RaceForgeAvatarRenderer();
        _timer = new Timer.Timer();
    }
    function onLayout(dc as Dc) as Void {}
    function onShow() as Void {
        if (_visible) { return; }
        _visible = true;
        _lastNow = System.getTimer();
        syncTimer();
    }
    function onHide() as Void {
        captureTime();
        _visible = false;
        syncTimer();
        _surface = null;
    }
    function onUpdate(dc as Dc) as Void {
        // One retained frame, not frame history. Publish the completed screen in
        // one blit so captions/limbs never disappear halfway through rendering.
        if (_surface == null || _surface.getWidth() != dc.getWidth() ||
            _surface.getHeight() != dc.getHeight()) {
            var ref = Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight()});
            _surface = ref.get() as Graphics.BufferedBitmap;
        }
        var surface = _surface as Graphics.BufferedBitmap;
        drawFrame(surface.getDc());
        dc.drawBitmap(0, 0, surface);
    }
    private function drawFrame(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var model = _demo.getModel();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 32, height * 14 / 260, 64, 24, 6);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 13 / 260, Graphics.FONT_XTINY, model.modeText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 38 / 260, Graphics.FONT_XTINY, model.workoutText, Graphics.TEXT_JUSTIFY_CENTER);
        var size = width * 124 / 260;
        _renderer.draw(dc, model, cx - size / 2, height * 57 / 260, size, height * 124 / 260);
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 180 / 260, Graphics.FONT_XTINY, model.dataText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var y = height * 202 / 260;
        dc.drawText(cx, y, headlineFont(dc, model.headline, y), model.headline, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 230 / 260, Graphics.FONT_XTINY, _demo.footer, Graphics.TEXT_JUSTIFY_CENTER);
    }
    function advanceDemo() as Void {
        captureTime();
        _demo.advance();
        syncTimer();
        if (_visible) { WatchUi.requestUpdate(); }
    }
    function setDemoMode(mode as Symbol) as Void {
        _demo.setMode(mode);
        _lastNow = System.getTimer();
        syncTimer();
        if (_visible) { WatchUi.requestUpdate(); }
    }
    function nextMode() as Void {
        setDemoMode(_demo.mode == :EASY_RUN ? :TEMPO_RUN : (_demo.mode == :TEMPO_RUN ? :POSES : :EASY_RUN));
    }
    function onAnimationTick() as Void {
        if (!_visible || _demo.paused || _demo.mode == :POSES) { return; }
        captureTime();
        syncTimer();
        WatchUi.requestUpdate();
    }
    function togglePause() as Void {
        captureTime();
        _demo.togglePause();
        syncTimer();
        if (_visible) { WatchUi.requestUpdate(); }
    }
    function isTimerRunning() as Boolean { return _timerRunning; }
    function animationTime() as Number { return _demo.animationTime(); }

    function headlineFont(dc as Dc, text as String, y as Number) as Graphics.FontType {
        return dc.getFontHeight(Graphics.FONT_TINY) <= 26 &&
               textFitsCircle(dc, text, Graphics.FONT_TINY, y) ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
    }
    function textFitsCircle(dc as Dc, text as String, font as Graphics.FontType, y as Number) as Boolean {
        var half = (dc.getTextWidthInPixels(text, font) + 1) / 2;
        var cy = dc.getHeight() / 2;
        var above = cy - y;
        var below = y + dc.getFontHeight(font) - cy;
        var dy = above > below ? above : below;
        var diameter = dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight();
        var radius = diameter / 2 - 4;
        return half * half + dy * dy <= radius * radius;
    }
    private function captureTime() as Void {
        var now = System.getTimer();
        var delta = now - _lastNow;
        _lastNow = now;
        if (_visible && !_demo.paused && delta > 0) { _demo.advanceTime(delta); }
    }
    private function syncTimer() as Void {
        var shouldRun = _visible && !_demo.paused && _demo.mode != :POSES && !_demo.isFinished();
        if (shouldRun && !_timerRunning) {
            _timer.start(method(:onAnimationTick), 250, true);
            _timerRunning = true;
        } else if (!shouldRun && _timerRunning) {
            _timer.stop();
            _timerRunning = false;
        }
    }
}
