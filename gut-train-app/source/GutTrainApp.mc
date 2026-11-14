import Toybox.Application;
import Toybox.Background;
import Toybox.Time;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class GutTrainApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new ActiveService() ];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        Background.registerForTemporalEvent(new Time.Duration(30 * 60));
        System.println("Gut Train started, target=" + Plan.target() + " g/h");
        var home = new ActiveHomeView();
        return [ home, new HomeDelegate(home) ];
    }
}
