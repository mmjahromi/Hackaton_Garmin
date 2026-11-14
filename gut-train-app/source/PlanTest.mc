import Toybox.Lang;
import Toybox.Test;

// Unit tests for the programme rules. Run them with
// "Monkey C: Run Tests" in VS Code; they are left out of normal builds.

(:test)
function raisesTargetWhenPlanHitAndGutGood(logger as Logger) as Boolean {
    return Plan.nextTarget(50, 50, 4) == 60;
}

(:test)
function countsWithinTenPercentAsHittingThePlan(logger as Logger) as Boolean {
    return Plan.nextTarget(50, 45, 5) == 60;
}

(:test)
function holdsTargetWhenUnderAteEvenIfGutGood(logger as Logger) as Boolean {
    return Plan.nextTarget(50, 44, 5) == 50;
}

(:test)
function holdsTargetWhenGutOnlyOk(logger as Logger) as Boolean {
    return Plan.nextTarget(60, 62, 3) == 60;
}

(:test)
function lowersTargetWhenGutRough(logger as Logger) as Boolean {
    return Plan.nextTarget(70, 70, 2) == 60 && Plan.nextTarget(70, 20, 1) == 60;
}

(:test)
function neverGoesAboveMaximum(logger as Logger) as Boolean {
    return Plan.nextTarget(90, 95, 5) == 90 && Plan.nextTarget(85, 85, 5) == 90;
}

(:test)
function neverGoesBelowMinimum(logger as Logger) as Boolean {
    return Plan.nextTarget(30, 10, 1) == 30 && Plan.nextTarget(35, 10, 1) == 30;
}

(:test)
function feedIntervalMeetsTheTarget(logger as Logger) as Boolean {
    // One 25 g gel every 30 min is 50 g/h; every 20 min is 75 g/h.
    return Plan.feedIntervalS(50) == 1800 && Plan.feedIntervalS(75) == 1200;
}

(:test)
function rateIsCarbsPerHour(logger as Logger) as Boolean {
    return Plan.rate(120, 7200) == 60 && Plan.rate(75, 3600) == 75;
}

(:test)
function veryShortSessionsHaveNoRate(logger as Logger) as Boolean {
    return Plan.rate(25, 30) == 0 && Plan.rate(25, 599) == 0;
}
