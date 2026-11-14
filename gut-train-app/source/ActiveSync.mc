import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;

(:background)
module ActiveSync {
    function post(record as Dictionary, callback as Method(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void) as Void {
        // Bound measured values only at the wire boundary; null is never zero.
        record["steps"] = ActiveData.bounded(record["steps"] as Number, 100000);
        record["activeMin"] = ActiveData.bounded(record["activeMin"] as Number, 1440);
        record["floors"] = ActiveData.bounded(record["floors"] as Number, 500);
        Communications.makeWebRequest("https://gut-train-web.vercel.app/api/days",
            record as Dictionary<Object, Object>, {
                :method=>Communications.HTTP_REQUEST_METHOD_POST,
                :headers=>{"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON},
                :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, callback);
    }
}
