import Toybox.Lang;

import Toybox.WatchUi;
class Delegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) { BehaviorDelegate.initialize(); view = v; }
    function onSelect() as Boolean { view.select(); return true; }
    function onNextPage() as Boolean { view.adjust(1); return true; }
    function onPreviousPage() as Boolean { view.adjust(-1); return true; }
    function onMenu() as Boolean { view.menu(); return true; }
    function onBack() as Boolean { return view.back(); }
}
