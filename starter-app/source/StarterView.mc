import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Number of times the screen has been tapped or select pressed.
var tapCount as Number = 0;

class StarterView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 40, Graphics.FONT_MEDIUM, "Hackathon",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 20, Graphics.FONT_NUMBER_MEDIUM, tapCount.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class StarterDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Fires on a screen tap or the select button.
    function onSelect() as Boolean {
        tapCount += 1;
        WatchUi.requestUpdate();
        return true;
    }
}
