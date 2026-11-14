import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// After the session: how did the gut cope? This one answer is what turns a
// fuel log into a training programme.
//
//   UP / DOWN = change the rating     START = confirm
class RatingView extends WatchUi.View {

    var rating as Number = 3;

    private const LABELS = ["Rough", "Uneasy", "OK", "Good", "Great"];

    function initialize() {
        View.initialize();
    }

    function change(delta as Number) as Void {
        var next = rating + delta;
        if (next >= 1 && next <= 5) {
            rating = next;
            WatchUi.requestUpdate();
        }
    }

    function label() as String {
        return LABELS[rating - 1];
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_SMALL, "How was your gut?", center);

        var color = Graphics.COLOR_YELLOW;
        if (rating >= 4) {
            color = Graphics.COLOR_GREEN;
        } else if (rating <= 2) {
            color = Graphics.COLOR_ORANGE;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.42, Graphics.FONT_LARGE, label(), center);

        // Five-step scale; the steps up to the chosen rating are filled.
        var gap = 30;
        var dotX = cx - gap * 2;
        var dotY = (h * 0.62).toNumber();
        for (var i = 0; i < 5; i++) {
            if (i < rating) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX + i * gap, dotY, 10);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX + i * gap, dotY, 7);
            }
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.79, Graphics.FONT_XTINY, "UP / DOWN, then START", center);
    }
}

class RatingDelegate extends WatchUi.BehaviorDelegate {

    private var _view as RatingView;
    private var _summary as Dictionary;

    function initialize(view as RatingView, summary as Dictionary) {
        BehaviorDelegate.initialize();
        _view = view;
        _summary = summary;
    }

    function onPreviousPage() as Boolean {
        _view.change(1);
        return true;
    }

    function onNextPage() as Boolean {
        _view.change(-1);
        return true;
    }

    function onSelect() as Boolean {
        confirm();
        return true;
    }

    // BACK also confirms, so a finished session is never lost.
    function onBack() as Boolean {
        confirm();
        return true;
    }

    private function confirm() as Void {
        var rating = _view.rating;
        var target = _summary["targetGph"] as Number;
        var rate = _summary["rateGph"] as Number;
        var next = Plan.nextTarget(target, rate, rating);

        _summary["gutRating"] = rating;
        _summary["nextTargetGph"] = next;

        // Demo sessions must not move the real programme.
        if (!demoMode) {
            Plan.saveSession(next);
        }
        WatchUi.switchToView(new SummaryView(_summary, _view.label()),
            new SummaryDelegate(), WatchUi.SLIDE_LEFT);
    }
}
