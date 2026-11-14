import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

// Foreground only: one request at a time avoids filling the BLE request queue.
class ActiveDemo {
    private var _index as Number = -1;
    private var _today as Number = 0;
    function initialize() {}
    function start() as Void {
        if (_index >= 0) { return; }
        _today = ActiveData.civilDay(Time.now());
        _index = 6;
        sendNext();
    }
    private function sendNext() as Void {
        var i = _index;
        var recovery = i == 3;
        var record = {"date"=>ActiveData.date(_today - i * 86400),
            "steps"=>6240 + i * 410, "activeMin"=>18 + i * 3, "floors"=>7 + i,
            "bodyBattery"=>recovery ? 24 : 65 + i, "dailyTarget"=>recovery ? 18 : 30,
            "weekTarget"=>150, "nudges"=>3 + i % 3, "nudgesAnswered"=>1 + i % 2,
            "recoveryDay"=>recovery, "demo"=>true};
        try { ActiveSync.post(record, method(:onSynced)); }
        catch (e) { _index = -1; System.println("Demo day sync could not start"); }
    }
    function onSynced(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        System.println("Demo day sync: " + code);
        _index -= 1;
        if (_index >= 0) { sendNext(); }
    }
}
