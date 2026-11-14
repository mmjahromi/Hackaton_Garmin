import Toybox.Lang;

// Pure snapshot adapter. No sensor acquisition, rule engine, clock or persistence.
// sourceStatus subkeys are configurable: the shared contract has not frozen them.
class RaceForgeAvatarAdapter {
    private var _hrKey as Symbol = :hr;
    private var _speedKey as Symbol = :speed;
    private var _animator as RaceForgeAvatarAnimator;

    function initialize() { _animator = new RaceForgeAvatarAnimator(); }

    function configureSourceKeys(hrKey as Symbol, speedKey as Symbol) as Void {
        _hrKey = hrKey; _speedKey = speedKey;
    }

    function fromPacePilot(features as Dictionary, decision as Dictionary,
                          lifecycle as Symbol, workoutType as Symbol,
                          animationTimeMs as Number) as RaceForgeAvatarModel {
        // No live HR thresholds: default context follows Decision alone.
        var context = new RaceForgeAvatarWorkoutContext(workoutType, 0.0f, 0.0f);
        return fromContext(features, decision, lifecycle, context, animationTimeMs);
    }

    function fromContext(features as Dictionary, decision as Dictionary,
                         lifecycle as Symbol, context as RaceForgeAvatarWorkoutContext,
                         animationTimeMs as Number) as RaceForgeAvatarModel {
        var model = new RaceForgeAvatarModel(:IDLE, "START MISSION", "HR --", "LIVE");
        var mode = features.get(:mode);
        // Unknown origin is explicitly unavailable, never silently LIVE.
        model.modeText = mode == :DEMO ? "DEMO" : (mode == :LIVE ? "LIVE" : "NO DATA");
        model.lifecycle = lifecycle;
        model.workoutType = context.workoutType;
        model.workoutText = context.workoutType == :TEMPO_RUN ? "TEMPO RUN" :
                           (context.workoutType == :WALK ? "WALK" :
                           (context.workoutType == :REST ? "REST" : "EASY RUN"));
        model.effortBand = context.effortBand;
        var advice = decision.get(:advice);
        model.advice = advice instanceof Symbol ? advice : :UNKNOWN;
        var reason = decision.get(:reason);
        model.reason = reason instanceof Symbol ? reason : :UNKNOWN;
        var id = decision.get(:decisionId);
        model.decisionId = id instanceof Number ? id : null;
        var resume = decision.get(:canResumeRun);
        model.canResumeRun = resume instanceof Boolean ? resume : false;
        var movement = features.get(:movement);
        model.movement = movement == :STILL ? :STILL : (movement == :MOVING ? :MOVING : :UNKNOWN);
        var hr = numeric(features.get(:hrBpm));
        var status = features.get(:sourceStatus);
        var hrValid = false;
        if (status instanceof Dictionary) {
            hrValid = status.get(_hrKey) == :VALID;
            if (status.get(_speedKey) == :VALID) {
                model.speedMps = numeric(features.get(:speedMps));
            }
        }
        var ready = features.get(:hrReady);
        hrValid = hrValid && ready instanceof Boolean && ready && hr != null && hr > 0;
        if (hrValid) { model.hrText = "HR " + (hr as Float).format("%.0f"); }
        var speed = model.speedMps;
        if (speed != null && speed > 0 && model.movement != :STILL) {
            var seconds = (1000.0f / speed).toNumber();
            // Implausibly slow values are unavailable; avoid unbounded labels.
            if (seconds <= 5999) {
                model.paceText = (seconds / 60).toString() + ":" +
                                 (seconds % 60).format("%02d") + "/km";
            }
        }
        if (lifecycle == :COMPLETE) {
            model.pose = :CELEBRATE; model.visualState = :CELEBRATING;
            model.motion = :CELEBRATE; model.headline = "MISSION COMPLETE";
        } else if (lifecycle == :PAUSED) {
            model.pose = :REST; model.visualState = :PAUSED;
            model.headline = "PAUSED";
        } else if (lifecycle == :ACTIVE && !hrValid) {
            model.pose = :UNKNOWN; model.visualState = :SENSOR_UNAVAILABLE;
            model.headline = "HR UNAVAILABLE";
        } else if (lifecycle == :READY) {
            model.visualState = :STARTING; model.motion = :START;
        } else if (lifecycle == :ACTIVE) {
            if (model.advice == :WALK) {
                model.pose = :WALK; model.visualState = :WALKING;
                model.motion = :WALK; model.headline = "WALK BREAK";
            } else if (model.advice == :READY_TO_RUN) {
                model.pose = :RECOVER;
                model.visualState = model.canResumeRun ? :READY_TO_RUN : :RECOVERING;
                model.motion = model.canResumeRun ? :START : :IDLE;
                model.headline = model.canResumeRun ? "READY? YOUR CHOICE" : "RECOVER COMFORTABLY";
            } else if (model.advice == :EASE_OFF) {
                model.pose = :EASE; model.motion = :RUN;
                model.visualState = :RUNNING_WINDED; model.flush = 1;
                model.headline = context.workoutType == :TEMPO_RUN ? "EASE SLIGHTLY" : "EASE YOUR PACE";
                if (context.sustained && context.effortBand == :VERY_HIGH) {
                    model.visualState = :RUNNING_EXHAUSTED; model.flush = 2;
                }
            } else if (model.advice == :RUN_EASY) {
                model.pose = :JOG; model.motion = :RUN;
                model.visualState = :RUNNING_HAPPY; model.headline = "NICE & EASY";
                if (context.workoutType == :REST) {
                    model.pose = :REST; model.motion = :IDLE;
                    model.visualState = :RECOVERING; model.headline = "RECOVER COMFORTABLY";
                } else if (context.workoutType == :WALK) {
                    model.pose = :WALK; model.motion = :WALK;
                    model.visualState = :WALKING; model.headline = "RECOVER COMFORTABLY";
                } else if (context.effortBand == :BELOW) {
                    model.headline = "STAY COMFORTABLE";
                    if (context.workoutType == :TEMPO_RUN && context.allowBuildEffort) {
                        model.visualState = :RUNNING_FOCUSED; model.headline = "BUILD EFFORT";
                    }
                } else if (context.effortBand == :TARGET) {
                    model.headline = context.workoutType == :TEMPO_RUN ? "HOLD YOUR RHYTHM" : "NICE RHYTHM";
                } else if (context.effortBand == :ABOVE || context.effortBand == :VERY_HIGH) {
                    // A high reading alone cannot issue EASE_OFF/WALK or an exhaustion face.
                    model.visualState = :RUNNING_FOCUSED;
                    model.headline = "FOLLOW COACH";
                }
            } else {
                model.headline = "FOLLOW COACH";
            }
        } else {
            model.headline = "WAITING FOR COACH";
        }
        if (model.movement == :STILL && (model.motion == :RUN || model.motion == :WALK)) {
            model.motion = :IDLE;
        }
        _animator.apply(model, animationTimeMs);
        model.dataText = model.hrText + "  " + model.paceText;
        return model;
    }

    private function numeric(value as Object?) as Float? {
        if (value instanceof Number || value instanceof Float) {
            var result = value.toFloat();
            if (result >= 0 && result <= 1000000.0f) { return result; }
        }
        return null;
    }
}
