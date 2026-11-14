import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

module GutTasks {
    function open(view) {
        var m=new WatchUi.Menu2({:title=>view == null ? "Gut Train tasks" : "Workout stopped"});
        if (view == null) {
            m.addItem(new WatchUi.MenuItem("Open PacePilot", "Exits Gut Train", :switch, {}));
            m.addItem(new WatchUi.MenuItem("Restart programme", "Confirmation required", :reset, {}));
        } else {
            m.addItem(new WatchUi.MenuItem("Log food portion", "Uses your chosen portion", :food, {}));
            m.addItem(new WatchUi.MenuItem("Log drink", "150 ml", :drink, {}));
            m.addItem(new WatchUi.MenuItem("Flag gut discomfort", null, :gut, {}));
            m.addItem(new WatchUi.MenuItem("Resume workout", null, :resume, {}));
            m.addItem(new WatchUi.MenuItem("Finish workout", "Confirmation required", :finish, {}));
            m.addItem(new WatchUi.MenuItem("Open PacePilot", "Finish workout first", :blocked, {}));
        }
        WatchUi.pushView(m,new GutTasksDelegate(view),WatchUi.SLIDE_IMMEDIATE);
    }
    function launchPace() {
        try { System.exitTo(new System.Intent("manifest-id://b21a5430-b50f-4e08-aca5-a95ab210aec8",null)); }
        catch(e) {
            var m=new WatchUi.Menu2({:title=>"PacePilot unavailable"});
            m.addItem(new WatchUi.MenuItem("Install PacePilot", "BACK returns", :info, {}));
            WatchUi.pushView(m,new WatchUi.Menu2InputDelegate(),WatchUi.SLIDE_IMMEDIATE);
        }
    }
}
class GutTasksDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    function initialize(v) { Menu2InputDelegate.initialize();view=v; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        var id=item.getId();
        if (id == :switch) { GutTasks.launchPace(); }
        if (id == :reset) { WatchUi.pushView(new WatchUi.Confirmation("Restart programme?"),new ResetDelegate(),WatchUi.SLIDE_IMMEDIATE); }
        if (view == null) { return; }
        if (id == :food) { view.logFeed(); }
        if (id == :drink) { view.logDrink(); }
        if (id == :gut) { view.logGutFlag(); }
        if (id == :resume) { view.togglePause(); }
        if (id == :finish || id == :blocked) { view.confirmFinish(); }
        WatchUi.requestUpdate();
    }
}
class GutFinishDelegate extends WatchUi.ConfirmationDelegate {
    var view;
    function initialize(v) { ConfirmationDelegate.initialize();view=v; }
    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) { view.finish(); }
        return true;
    }
}
