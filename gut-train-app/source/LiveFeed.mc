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
    var stress=null;
    var stressAt=null;
    var stressCheckedMs=null;
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
    function addStress(body, nowMs, now) {
        body["stress"]=null; body["stressAt"]=null;
        if (!body["status"].equals("active")) { return; }
        if (StressPolicy.shouldRefresh(nowMs, stressCheckedMs)) {
            // Cache missing/failed reads too, so they cannot trigger rapid retries.
            stressCheckedMs=nowMs; stress=null; stressAt=null;
            readStress(now);
        }
        // Revalidate the timestamp in case the wall clock was corrected backwards.
        if (StressPolicy.valid(stress, stressAt, now)) {
            body["stress"]=stress; body["stressAt"]=stressAt;
        }
    }
    function readStress(now) {
        if (!(Toybox has :SensorHistory) || !(Toybox.SensorHistory has :getStressHistory)) { return; }
        try {
            var history=Toybox.SensorHistory.getStressHistory({
                :period=>1, :order=>Toybox.SensorHistory.ORDER_NEWEST_FIRST});
            if (history == null) { return; }
            var sample=history.next();
            if (sample == null || !(sample has :data) || !(sample has :when) ||
                sample.data == null || sample.when == null) { return; }
            var at=sample.when.value();
            if (StressPolicy.valid(sample.data, at, now)) {
                stress=sample.data.toNumber(); stressAt=at;
            }
        } catch(e) {
            // Unavailable history must not prevent the existing live packet.
        }
    }
    function transmit(body) {
        addStress(body,System.getTimer(),Time.now().value());
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
