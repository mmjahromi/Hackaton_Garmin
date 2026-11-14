import Toybox.Lang;

// Optional PRESENTATION metadata, separate from PacePilot's frozen dictionaries.
// Live callers supply an interpreted effort band; only DEMO evaluates HR ranges.
class RaceForgeAvatarWorkoutContext {
    var workoutType as Symbol;
    var lowerBpm as Float;
    var upperBpm as Float;
    var highMarginBpm as Float = 25.0f;
    var effortBand as Symbol = :UNKNOWN;
    var sustained as Boolean = false;
    var allowBuildEffort as Boolean = false;

    function initialize(type as Symbol, lower as Float, upper as Float) {
        workoutType = type;
        lowerBpm = lower;
        upperBpm = upper;
    }

    // Illustrative UI classification only. Never returns or changes advice.
    function setDemoEffort(hr as Float?, sustainedMs as Number) as Void {
        sustained = sustainedMs >= 8000;
        effortBand = :UNKNOWN;
        if (hr == null || lowerBpm <= 0 || upperBpm < lowerBpm) { return; }
        if (hr < lowerBpm) { effortBand = :BELOW; }
        else if (hr <= upperBpm) { effortBand = :TARGET; }
        else if (hr >= upperBpm + highMarginBpm) { effortBand = :VERY_HIGH; }
        else { effortBand = :ABOVE; }
    }
}
