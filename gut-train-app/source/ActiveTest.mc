import Toybox.Lang;
import Toybox.Test;

(:test)
function activeIncreaseAndRounding(logger as Logger) as Boolean {
    return Active.nextWeekTarget(150, 150) == 165 &&
        Active.nextWeekTarget(165, 190) == 180 && Active.nextWeekTarget(175, 175) == 195;
}
(:test)
function activeDecreaseAndBoundary(logger as Logger) as Boolean {
    return Active.nextWeekTarget(150, 119) == 135 && Active.nextWeekTarget(175, 0) == 160 &&
        Active.nextWeekTarget(150, 120) == 150 && Active.nextWeekTarget(150, 149) == 150;
}
(:test)
function activeCapsAndFloors(logger as Logger) as Boolean {
    return Active.nextWeekTarget(300, 350) == 300 && Active.nextWeekTarget(290, 290) == 300 &&
        Active.nextWeekTarget(60, 0) == 60 && Active.nextWeekTarget(65, 0) == 60;
}
(:test)
function activeDailyCeilingAndRemainingDays(logger as Logger) as Boolean {
    return Active.todayTarget(150, 0, 7, null) == 22 &&
        Active.todayTarget(150, 30, 6, 30) == 20 && Active.todayTarget(150, 100, 1, 70) == 50;
}
(:test)
function activeDailyFloorAndRecoveryOrder(logger as Logger) as Boolean {
    return Active.todayTarget(150, 150, 7, null) == 10 &&
        Active.todayTarget(150, 200, 1, 80) == 10 &&
        Active.todayTarget(150, 200, 1, 29) == 6 && Active.todayTarget(150, 0, 7, 29) == 14;
}
(:test)
function activeRecoveryThreshold(logger as Logger) as Boolean {
    return !Active.isRecoveryDay(null) && !Active.isRecoveryDay(30) &&
        !Active.isRecoveryDay(100) && Active.isRecoveryDay(29) && Active.isRecoveryDay(0);
}

(:test)
function activeCivilWeekBoundaries(logger as Logger) as Boolean {
    // Civil UTC date tokens: Monday 2026-11-09, Sunday 15, Monday 16.
    var mon = Toybox.Time.Gregorian.moment({:year=>2026, :month=>11, :day=>9,
        :hour=>0, :minute=>0, :second=>0}).value();
    return ActiveData.monday(mon) == mon && ActiveData.monday(mon + 6*86400) == mon &&
        ActiveData.monday(mon + 7*86400) == mon + 7*86400 &&
        ActiveData.date(mon - 10*86400).equals("2026-10-30");
}
