import Toybox.Lang;

(:background)
module Active {
    function nextWeekTarget(lastTarget as Number, lastActual as Number) as Number {
        if (lastActual >= lastTarget) {
            var up = ((lastTarget * 11 + 25) / 50) * 5;
            return up > 300 ? 300 : up;
        }
        if (lastActual * 5 < lastTarget * 4) {
            var down = ((lastTarget * 9 + 25) / 50) * 5;
            return down < 60 ? 60 : down;
        }
        return lastTarget;
    }

    function isRecoveryDay(bodyBattery as Number?) as Boolean {
        return bodyBattery != null && bodyBattery < 30;
    }

    function todayTarget(weekTarget as Number, doneBeforeToday as Number,
                         daysLeftIncludingToday as Number, bodyBattery as Number?) as Number {
        var remaining = weekTarget - doneBeforeToday;
        var normal = (remaining + daysLeftIncludingToday - 1) / daysLeftIncludingToday;
        if (normal < 10) { normal = 10; }
        // Recovery is applied AFTER the normal 10-minute floor (minimum 6).
        return isRecoveryDay(bodyBattery) ? (normal * 3 + 4) / 5 : normal;
    }
}
