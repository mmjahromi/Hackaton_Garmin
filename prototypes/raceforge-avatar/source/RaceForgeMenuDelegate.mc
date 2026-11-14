import Toybox.Lang;
import Toybox.WatchUi;

class RaceForgeMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _view as RaceForgeView;

    function initialize(view as RaceForgeView) {
        MenuInputDelegate.initialize();
        _view = view;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :item_1) {
            _view.setDemoMode(:EASY_RUN);
        } else if (item == :item_2) {
            _view.setDemoMode(:TEMPO_RUN);
        } else if (item == :poses) {
            _view.setDemoMode(:POSES);
        } else if (item == :freeze) {
            _view.togglePause();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}
