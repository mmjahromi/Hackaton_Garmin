import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TaskMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    function initialize(v) { Menu2InputDelegate.initialize(); view=v; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        view.task(item.getId());
    }
}
module AppSwitch {
    function openGut() {
        try {
            System.exitTo(new System.Intent("manifest-id://eb469543-a0a5-4bc4-b337-b8361a381f06", null));
        } catch(e) {
            var m=new WatchUi.Menu2({:title=>"Gut Train unavailable"});
            m.addItem(new WatchUi.MenuItem("Install Gut Train", "BACK returns", :info, {}));
            WatchUi.pushView(m,new WatchUi.Menu2InputDelegate(),WatchUi.SLIDE_IMMEDIATE);
        }
    }
}
