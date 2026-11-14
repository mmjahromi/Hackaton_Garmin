import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Session counts and the daily streak, kept in on-watch storage.
module Stats {

    function record() as Void {
        var today = Time.today().value();
        var lastDay = Application.Storage.getValue("lastDay") as Number?;
        var streak = Application.Storage.getValue("streak") as Number?;
        var todayCount = Application.Storage.getValue("todayCount") as Number?;

        if (lastDay != null && lastDay == today) {
            todayCount = (todayCount == null) ? 1 : todayCount + 1;
            if (streak == null) {
                streak = 1;
            }
        } else {
            // 25 hours allows for a daylight-saving day.
            var consecutive = lastDay != null && (today - lastDay) <= 25 * 3600;
            streak = (consecutive && streak != null) ? streak + 1 : 1;
            todayCount = 1;
        }

        Application.Storage.setValue("lastDay", today);
        Application.Storage.setValue("streak", streak);
        Application.Storage.setValue("todayCount", todayCount);
        Application.Storage.setValue("lastSessionAt", Time.now().value());
    }

    function todayCount() as Number {
        var today = Time.today().value();
        var lastDay = Application.Storage.getValue("lastDay") as Number?;
        var count = Application.Storage.getValue("todayCount") as Number?;
        if (lastDay != null && lastDay == today && count != null) {
            return count;
        }
        return 0;
    }

    function streak() as Number {
        var value = Application.Storage.getValue("streak") as Number?;
        return (value == null) ? 0 : value;
    }
}
