import Toybox.Lang;
import Toybox.WatchUi;

class RaceForgeDelegate extends WatchUi.BehaviorDelegate {
    private var _view as RaceForgeView;

    function initialize(view as RaceForgeView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.advanceDemo();
        return true;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new RaceForgeMenuDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.nextMode();
        return true;
    }

    function onNextPage() as Boolean {
        _view.togglePause();
        return true;
    }

}
