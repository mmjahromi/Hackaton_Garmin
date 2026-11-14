import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Demo mode speeds up the session clock so each feed comes round in five
// seconds. Screens are labelled DEMO and nothing is saved to
// the activity history. Toggle it with the DOWN button on this screen.
var demoMode as Boolean = false;

class HomeDelegate extends WatchUi.BehaviorDelegate {
    private var _home as ActiveHomeView;

    function initialize(home as ActiveHomeView) {
        BehaviorDelegate.initialize();
        _home = home;
    }

    function onSelect() as Boolean {
        var view = new NutritionSetup(null, "");
        WatchUi.pushView(view, new NutritionDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }

    // Holding UP (the menu gesture) offers to restart the programme.
    function onMenu() as Boolean {
        GutTasks.open(null);
        return true;
    }

    // DOWN button toggles demo mode.
    function onNextPage() as Boolean {
        demoMode = !demoMode;
        _home.demoChanged();
        WatchUi.requestUpdate();
        return true;
    }
}

class ResetDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            Plan.reset();
        }
        return true;
    }
}
