import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RaceForgeApp extends Application.AppBase {
    var adventure;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        if (adventure != null) { adventure.shutdown(); }
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        adventure = new RaceForgeAdventureView();
        return [ adventure, new RaceForgeAdventureDelegate(adventure) ];
    }

}

function getApp() as RaceForgeApp {
    return Application.getApp() as RaceForgeApp;
}
