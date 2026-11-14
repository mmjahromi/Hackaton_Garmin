import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class BreatheApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // 5 minutes is the shortest interval Connect IQ allows.
        Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        System.println("Breathe started, stress=" + Stress.current());
        return [ new HomeView(), new HomeDelegate() ];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new BreatheService() ];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }
}
