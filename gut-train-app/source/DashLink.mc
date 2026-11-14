import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

// Reaches the shared dashboard once when the app opens, so the home screen
// can say whether it is connected and the dashboard can show "Gut Train
// checked in". The request carries only the app's name: no health data.
// The app works the same without it.
module DashLinkText {
    function status(code) {
        if (code == null) { return "Dashboard: connecting"; }
        return code == 200 ? "Dashboard connected" : "Dashboard not connected";
    }
}

class DashLink {
    var code = null;
    var started = false;
    function initialize() {}
    function connect() {
        if (started) { return; }
        started = true;
        try {
            Communications.makeWebRequest("https://gut-train-web.vercel.app/api/watch-config",
                {"app" => "guttrain"},
                {:method => Communications.HTTP_REQUEST_METHOD_GET,
                 :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
                method(:onResult));
        } catch (e) { code = -1; }
    }
    function onResult(result as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        code = result;
        WatchUi.requestUpdate();
    }
    function text() { return started ? DashLinkText.status(code) : ""; }
}
