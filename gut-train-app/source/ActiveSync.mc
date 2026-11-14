import Toybox.Lang;
import Toybox.PersistedContent;

(:background)
module ActiveSync {
    function post(record as Dictionary, callback as Method(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void) as Void {
        // Daily activity stays local. The shared demo accepts only explicit
        // foreground session sharing; background uploads had no consent UI.
        callback.invoke(204, null);
    }
}
