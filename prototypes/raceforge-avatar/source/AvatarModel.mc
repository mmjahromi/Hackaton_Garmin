import Toybox.Lang;

// Presentation data only. No sensor access or advice decisions.
class RaceForgeAvatarModel {
    var pose as Symbol;
    var headline as String;
    var hrText as String;
    var modeText as String;
    var visualState as Symbol = :IDLE;
    var motion as Symbol = :IDLE;
    var frame as Number = 0;
    var breath as Number = 0;
    var bob as Number = 0;
    var readyLean as Number = 0;
    var showSweat as Boolean = false;
    var flush as Number = 0;
    var speedMps as Float? = null;
    var movement as Symbol = :UNKNOWN;
    var workoutType as Symbol = :EASY_RUN;
    var workoutText as String = "EASY RUN";
    var paceText as String = "PACE --";
    var advice as Symbol = :RUN_EASY;
    var reason as Symbol = :DEMO_SCRIPT;
    var decisionId as Number? = null;
    var canResumeRun as Boolean = false;
    var lifecycle as Symbol = :READY;
    var effortBand as Symbol = :UNKNOWN;
    var dataText as String = "HR --  PACE --";

    function initialize(poseValue as Symbol, headlineValue as String,
                        hrValue as String, modeValue as String) {
        pose = poseValue;
        headline = headlineValue;
        hrText = hrValue;
        modeText = modeValue;
        dataText = hrValue + "  PACE --";
        if (pose == :JOG) {
            visualState = :RUNNING_HAPPY; motion = :RUN;
        } else if (pose == :EASE) {
            visualState = :RUNNING_WINDED; motion = :RUN;
        } else if (pose == :WALK) {
            visualState = :WALKING; motion = :WALK;
        } else if (pose == :RECOVER) {
            visualState = :READY_TO_RUN; motion = :START; readyLean = 2;
        } else if (pose == :CELEBRATE) {
            visualState = :CELEBRATING; motion = :CELEBRATE;
        }
    }
}
