import Toybox.Lang;

// Pure presentation boundary: never mutates the controller's dictionaries.
class AvatarBridge {
    var adapter;
    function initialize() {
        adapter = new RaceForgeAvatarAdapter();
        adapter.configureSourceKeys(:hr, :speed);
    }
    function lifecycle(value) {
        if (value == :ACTIVE || value == :PAUSED || value == :COMPLETE) { return value; }
        return :READY; // Includes setup (no controller yet).
    }
    function sourceStatus(value) {
        // FeaturePipeline publishes these symbols, not strings or reading objects.
        if (value == :VALID || value == :STALE || value == :UNSUPPORTED || value == :ERROR) { return value; }
        return :MISSING;
    }
    function snapshot(f) {
        var s = f.get(:sourceStatus);
        if (!(s instanceof Dictionary)) { s = {}; }
        return {:mode=>f.get(:mode), :hrBpm=>f.get(:hrBpm),
            :hrReady=>f.get(:hrReady) == true, :speedMps=>f.get(:speedMps),
            :movement=>f.get(:movement), :terrain=>f.get(:terrain),
            :sourceStatus=>{:hr=>sourceStatus(s.get(:hr)), :speed=>sourceStatus(s.get(:speed))}};
    }
    function decision(d) {
        var advice = d.get(:advice);
        if (advice != :RUN_EASY && advice != :EASE_OFF && advice != :WALK && advice != :READY_TO_RUN) { advice = :UNKNOWN; }
        return {:advice=>advice, :reason=>d.hasKey(:reason) ? d[:reason] : :UNKNOWN,
            :decisionId=>d.hasKey(:decisionId) ? d[:decisionId] : null,
            :canResumeRun=>d.get(:canResumeRun) == true};
    }
    function context(f, d, config) {
        var ctx = new RaceForgeAvatarWorkoutContext(:EASY_RUN, config[:hrLowBpm].toFloat(), config[:hrHighBpm].toFloat());
        var valid = f[:sourceStatus][:hr] == :VALID && f[:hrReady];
        var band = HrFeedback.state(f[:hrBpm], valid, config[:hrLowBpm], config[:hrHighBpm]);
        if (band == :LOW) { ctx.effortBand = :BELOW; }
        else if (band == :IN_BAND) { ctx.effortBand = :TARGET; }
        else if (band == :HIGH) { ctx.effortBand = :VERY_HIGH; }
        // HrFeedback's NEAR means up to five bpm outside either chosen bound.
        else if (band == :NEAR) { ctx.effortBand = f[:hrBpm] < config[:hrLowBpm] ? :BELOW : :ABOVE; }
        ctx.sustained = d[:advice] == :EASE_OFF || d[:advice] == :WALK;
        ctx.allowBuildEffort = false;
        return ctx;
    }
    function model(features, coachDecision, state, config, timeMs) {
        var f = snapshot(features);
        var d = decision(coachDecision);
        var m = adapter.fromContext(f, d, lifecycle(state), context(f, d, config), timeMs);
        if (m.modeText.equals("DEMO")) { m.modeText = "DEMO 4x"; }
        return m;
    }
}
