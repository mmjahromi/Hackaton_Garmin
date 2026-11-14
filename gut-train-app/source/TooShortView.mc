import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Shown when a session ends before ten minutes: nothing is saved and the
// target is left alone.
class TooShortView extends WatchUi.View {

    private var _target as Number;

    function initialize(target as Number) {
        View.initialize();
        _target = target;
    }

    function onUpdate(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.28, Graphics.FONT_MEDIUM, "Too short", center);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.44, Graphics.FONT_XTINY, "Under 10 minutes, not counted", center);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.60, Graphics.FONT_XTINY, "TARGET STAYS", center);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.73, Graphics.FONT_MEDIUM, _target + " g/h", center);
    }
}
