import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

var nutritionFood as String = "gel";
var nutritionShare as Boolean = false;
var nutritionPortion as Number = 25;
var nutritionDrinkSec as Number = 900;

module NutritionPlan {
    function adjusted(target as Number, delta as Number) as Number {
        var next = target + delta * 5;
        return next < 30 ? 30 : (next > 90 ? 90 : next);
    }
    function remember(summary as Dictionary) as Boolean {
        if (demoMode) { return true; }
        try {
            var history = Application.Storage.getValue("nutrition-history");
            if (!(history instanceof Array)) { history = []; }
            history.add(summary);
            while (history.size() > 20) { history = history.slice(1, history.size()); }
            Application.Storage.setValue("nutrition-history", history);
            return true;
        } catch (e) { return false; }
    }
}
class NutritionSetup extends WatchUi.View {
    var target as Number;
    var stage as Number = 0;
    var food as Number = 0;
    var portion as Number = 25;
    var drinkIndex as Number = 2;
    const DRINKS = [0, 600, 900, 1200];
    var sharing as Boolean = false;
    var summary as Dictionary?;
    var label as String;
    const FOODS = ["gel", "chews", "drink", "food"];
    function initialize(record as Dictionary?, gutLabel as String) {
        View.initialize();
        summary = record; label = gutLabel;
        target = record == null ? Plan.target() : record["targetGph"] as Number;
    }
    function change(delta as Number) as Void {
        if (stage == 0) { target = NutritionPlan.adjusted(target, delta); }
        if (stage == 1) { food = (food + delta + 4) % 4; }
        if (stage == 2) {
            var next = portion + delta * 5;
            portion = next < 5 ? 5 : (next > 60 ? 60 : next);
        }
        if (stage == 3) { drinkIndex = (drinkIndex + delta + 4) % 4; }
        if (stage == 4) { sharing = !sharing; }
        WatchUi.requestUpdate();
    }
    function confirm() as Void {
        var record = summary;
        if (record != null) {
            record["nextTargetGph"] = target;
            record["targetConfirmed"] = true;
            record["localSaved"] = NutritionPlan.remember(record);
            if (!demoMode) {
                try { Plan.saveSession(target); }
                catch (e) { record["localSaved"] = false; }
            }
            WatchUi.switchToView(new SummaryView(record, label), new SummaryDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (stage < 5) { stage++; WatchUi.requestUpdate(); return; }
        nutritionFood = FOODS[food];
        nutritionShare = sharing;
        nutritionPortion = portion; nutritionDrinkSec = DRINKS[drinkIndex];
        var session = new SessionView(target);
        WatchUi.switchToView(session, new SessionDelegate(session), WatchUi.SLIDE_LEFT);
    }
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK); dc.clear();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var title = summary == null ? ["Your fuel plan", "What will you log?", "Carbs per portion", "Drink cue interval", "Share live + summary?", "Confirm your plan"][stage] : "Next session plan";
        var options = [target + " g/h", FOODS[food], portion + " g",
            drinkIndex == 0 ? "Off" : (DRINKS[drinkIndex] / 60) + " min",
            sharing ? "Public demo site" : "Keep on watch", target + " g/h"];
        var text = summary != null ? target + " g/h" : options[stage];
        dc.setColor(Graphics.COLOR_LT_GRAY,Graphics.COLOR_TRANSPARENT);
        dc.drawText(130,35,Graphics.FONT_XTINY,demoMode ? "NUTRITION / DEMO" : "NUTRITION",center);
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_TRANSPARENT);
        dc.drawText(130,78,Graphics.FONT_SMALL,title,center);
        dc.setColor(Graphics.COLOR_ORANGE,Graphics.COLOR_TRANSPARENT);
        dc.drawText(130,118,Graphics.FONT_MEDIUM,text,center);
        dc.setColor(Graphics.COLOR_LT_GRAY,Graphics.COLOR_TRANSPARENT);
        dc.drawText(130,155,Graphics.FONT_XTINY,stage == 4 ? "gut-train-web.vercel.app" : "Use your own fueling plan",center);
        dc.drawText(130,182,Graphics.FONT_XTINY,"UP / DOWN adjusts",center);
        dc.drawText(130,210,Graphics.FONT_XTINY,"START confirms",center);
    }
}
class NutritionDelegate extends WatchUi.BehaviorDelegate {
    var view as NutritionSetup;
    function initialize(v as NutritionSetup) { BehaviorDelegate.initialize(); view = v; }
    function onSelect() as Boolean { view.confirm(); return true; }
    function onPreviousPage() as Boolean { view.change(1); return true; }
    function onNextPage() as Boolean { view.change(-1); return true; }
    function onBack() as Boolean {
        if (view.summary != null) { return true; }
        if (view.stage > 0) { view.stage--; WatchUi.requestUpdate(); }
        else { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        return true;
    }
}
