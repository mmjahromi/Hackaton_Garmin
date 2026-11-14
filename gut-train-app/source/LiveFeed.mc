import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

module LiveFeedPolicy {
    function due(consent, mode, busy, now, last, changed) {
        return consent && mode.equals("LIVE") && !busy && (changed || last == null || now < last || now-last >= 5000);
    }
}
// At most one live request in flight. No backlog of sensor readings.
class LiveFeed {
    var busy=false;
    var lastAt=null;
    var lastStatus="";
    var sequence=0;
    var pending=null;
    var status="Live sharing off";
    function initialize() {}
    function send(body,consent) {
        if (!consent || !body["mode"].equals("LIVE")) { return; }
        if (lastStatus.equals("completed") && status.equals("Live link connected")) { return; }
        // The first resumed packet must not relabel pre-pause readings as fresh.
        var previous=pending == null ? lastStatus : pending["status"];
        if (previous.equals("paused") && body["status"].equals("active")) {
            body["heartRate"]=null; body["speedMps"]=null;
        }
        body["sampledAt"]=Time.now().value();
        if (busy) {
            if (pending != null || !body["status"].equals(lastStatus)) { pending=body; }
            return;
        }
        if (!LiveFeedPolicy.due(consent,body["mode"],busy,System.getTimer(),lastAt,!body["status"].equals(lastStatus))) { return; }
        transmit(body);
    }
    function transmit(body) {
        busy=true;lastAt=System.getTimer();lastStatus=body["status"];
        sequence++;body["sequence"]=sequence;
        status="Sending live data";
        try {
            Communications.makeWebRequest("https://gut-train-web.vercel.app/api/live",body,
              {:method=>Communications.HTTP_REQUEST_METHOD_POST,
               :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON},
               :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onResult));
        } catch(e) { busy=false;status="Live link unavailable"; }
    }
    function onResult(code as Number,data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        busy=false;
        status=code==200 ? "Live link connected" : "Live link unavailable";
        if (pending != null) {var body=pending;pending=null;transmit(body);}
    }
}
