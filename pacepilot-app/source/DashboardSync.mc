import Toybox.Communications;
import Toybox.PersistedContent;
import Toybox.Lang;
import Toybox.WatchUi;

class DashboardSync {
    var status = "Kept on watch";
    function initialize() {}
    function send(summary, consent) {
        if (!consent || summary[:mode] == :DEMO) { return; }
        var body = new SummaryStore().encode(summary);
        status = "Sharing...";
        try {
            Communications.makeWebRequest("https://gut-train-web.vercel.app/api/pace-sessions", body,
                {:method=>Communications.HTTP_REQUEST_METHOD_POST,
                 :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON},
                 :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
                method(:onResult));
        } catch (e) { status = "Share failed / retry"; }
    }
    function onResult(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        status = code == 200 || code == 201 ? "Shared to dashboard" : "Share failed / retry";
        WatchUi.requestUpdate();
    }
}
