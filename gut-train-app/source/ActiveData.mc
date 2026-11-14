import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Shared, small background-safe data layer. Never uses UI, Timer or live Sensor.
(:background)
module ActiveData {
    // A civil date encoded as UTC midnight, NOT an instant of local midnight.
    // Doing calendar arithmetic on this value avoids 23/25-hour DST days.
    function civilDay(moment as Time.Moment) as Number {
        var d = Gregorian.info(moment, Time.FORMAT_SHORT);
        return Gregorian.moment({:year=>d.year, :month=>(d.month as Number), :day=>d.day,
            :hour=>0, :minute=>0, :second=>0}).value();
    }
    function date(day as Number) as String {
        var d = Gregorian.utcInfo(new Time.Moment(day), Time.FORMAT_SHORT);
        return d.year.format("%04d") + "-" + (d.month as Number).format("%02d") + "-" + d.day.format("%02d");
    }
    function monday(day as Number) as Number {
        var d = Gregorian.utcInfo(new Time.Moment(day), Time.FORMAT_SHORT);
        return day - (((d.day_of_week as Number) + 5) % 7) * 86400;
    }
    function bounded(value as Number, maximum as Number) as Number {
        return value < 0 ? 0 : (value > maximum ? maximum : value);
    }
    function count(key as String) as Number {
        var n = Application.Storage.getValue(key) as Number?;
        return n == null ? 0 : n;
    }
    function resetDay(day as Number) as Void {
        if ((Application.Storage.getValue("activeDay") as Number?) != day) {
            Application.Storage.setValue("activeDay", day);
            Application.Storage.setValue("activeNudges", 0);
            Application.Storage.setValue("activeAnswered", 0);
            Application.Storage.deleteValue("activePending");
            Application.Storage.deleteValue("activeBattery");
            Application.Storage.deleteValue("activeBatteryRead");
        }
    }
    function morningBattery(now as Time.Moment, day as Number) as Number? {
        var hour = Gregorian.info(now, Time.FORMAT_SHORT).hour;
        if (hour < 11 && (Application.Storage.getValue("activeBatteryRead") as Number?) != day) {
            // Exactly one attempt each morning; never reuse yesterday's sample.
            Application.Storage.setValue("activeBatteryRead", day);
            if (SensorHistory has :getBodyBatteryHistory) {
                var sample = SensorHistory.getBodyBatteryHistory({:period=>1,
                    :order=>SensorHistory.ORDER_NEWEST_FIRST}).next();
                if (sample != null && sample.data != null && civilDay(sample.when) == day &&
                    sample.when.value() <= now.value() &&
                    Gregorian.info(sample.when, Time.FORMAT_SHORT).hour < 11) {
                    var value = (sample.data as Number or Float).toNumber();
                    if (value >= 0 && value <= 100) {
                        Application.Storage.setValue("activeBattery", value);
                    }
                }
            }
        }
        return Application.Storage.getValue("activeBattery") as Number?;
    }
    function week(day as Number) as Dictionary {
        var start = monday(day);
        var previous = 0;
        var done = 0;
        // SDK history: at most seven days, newest first. Sum only available
        // samples in the requested civil-date window, never extrapolate.
        var history = ActivityMonitor.getHistory();
        for (var i = 0; i < history.size(); i++) {
            var item = history[i];
            if (item.startOfDay == null || !(item has :activeMinutes) || item.activeMinutes == null) { continue; }
            var when = civilDay(item.startOfDay as Time.Moment);
            var minutes = (item.activeMinutes as ActivityMonitor.ActiveMinutes).total;
            if (when >= start - 7 * 86400 && when < start) { previous += minutes; }
            if (when >= start && when < day) { done += minutes; }
        }
        var state = Application.Storage.getValue("activeWeek") as Dictionary?;
        var target = 150;
        if (state != null) {
            target = state["target"] as Number;
            if ((state["monday"] as Number) < start) {
                // After an absence, roll once using the immediately preceding
                // week available in history; don't invent unobserved weeks.
                target = Active.nextWeekTarget(target, previous);
            }
        }
        var result = {"monday"=>start, "date"=>date(start), "target"=>target, "done"=>done};
        Application.Storage.setValue("activeWeek", result);
        return result;
    }
    function record() as Dictionary {
        var now = Time.now();
        var day = civilDay(now);
        resetDay(day);
        var state = week(day);
        var battery = morningBattery(now, day);
        var info = ActivityMonitor.getInfo();
        var active = null as Number?;
        if (info has :activeMinutesDay && info.activeMinutesDay != null) { active = (info.activeMinutesDay as ActivityMonitor.ActiveMinutes).total; }
        var floors = null as Number?;
        if (info has :floorsClimbed) { floors = info.floorsClimbed; }
        var target = state["target"] as Number;
        return {"date"=>date(day), "steps"=>info.steps, "activeMin"=>active, "floors"=>floors,
            "bodyBattery"=>battery,
            "dailyTarget"=>Active.todayTarget(target, state["done"] as Number,
                7 - (day - (state["monday"] as Number)) / 86400, battery),
            "weekTarget"=>target, "nudges"=>count("activeNudges"),
            "nudgesAnswered"=>count("activeAnswered"), "recoveryDay"=>Active.isRecoveryDay(battery), "demo"=>false};
    }
    function ready(record as Dictionary) as Boolean {
        // Contract disallows null for these fields. Don't upload invented zeros.
        return (record["steps"] as Number?) != null && (record["activeMin"] as Number?) != null &&
            (record["floors"] as Number?) != null;
    }
}
