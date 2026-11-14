// Clock is supplied by the app or tests. Providers and stores are injectable.
class SessionController {
    var config;
    var provider;
    var pipeline;
    var engine;
    var store;
    var mode;
    var lifecycle = :READY;
    var memory;
    var decision;
    var features;
    var previousNow = null;
    var events = [];
    var sessionSec = 0.0;
    var movingSec = 0.0;
    var unknownMotionSec = 0.0;
    var hrValidSec = 0.0;
    var walkPromptCount = 0;
    var transitions = [];
    var summary = null;
    var saved = true;
    var sessionId = 0;
    var endedAt = 0;
    function initialize(c, p, storage, selectedMode) {
        config = c; provider = p; store = storage; mode = selectedMode;
        pipeline = new FeaturePipeline(c); engine = new CoachEngine(c);
        memory = engine.initialMemory();
        features = pipeline.update(Contracts.emptyFrame(0, mode, 0), 0);
        decision = engine.step(features, memory, 0, null)[:decision];
    }
    function setMode(selected) {
        if (lifecycle != :READY || (selected != :LIVE && selected != :DEMO)) { return false; }
        provider.stop();
        provider = selected == :LIVE ? new LiveProvider() : new ReplayProvider(:STANDARD);
        mode = selected; pipeline.reset(); memory = engine.initialMemory();
        return true;
    }
    function dispatch(event) {
        if (events.indexOf(event) == -1 && events.size() < 8) { events.add(event); }
    }
    function resetDwell() {
        engine.clearDwell(memory);
        if (memory[:advice] == :READY_TO_RUN) { memory[:advice] = :WALK; memory[:decisionId]++; }
    }
    function finish(goalMet) {
        if (lifecycle == :COMPLETE) { return; }
        lifecycle = :COMPLETE;
        provider.stop();
        summary = {:schemaVersion=>1, :sessionId=>sessionId, :mode=>mode,
            :goalSec=>config[:goalSec], :sessionSec=>sessionSec, :movingSec=>movingSec,
            :unknownMotionSec=>unknownMotionSec, :hrValidSec=>hrValidSec,
            :walkPromptCount=>walkPromptCount, :goalMet=>goalMet, :endedAt=>endedAt};
        saved = mode == :DEMO ? true : store.save(summary);
    }
    function tick(now) {
        if (previousNow != null && now < previousNow) { return; }
        var queued = events;
        events = [];
        if (lifecycle == :READY) {
            if (queued.indexOf(:START) == -1 || !Config.valid(config)) { return; }
            provider.start(); pipeline.reset(); memory = engine.initialMemory();
            sessionSec = 0.0; movingSec = 0.0; unknownMotionSec = 0.0; hrValidSec = 0.0;
            walkPromptCount = 0; transitions = []; summary = null; saved = true;
            previousNow = now; lifecycle = :ACTIVE;
            features = pipeline.update(provider.snapshot(now), now);
            decision = engine.step(features, memory, 0, null)[:decision];
            return;
        }
        if (lifecycle == :COMPLETE) {
            if (queued.indexOf(:RESET) != -1) { lifecycle = :READY; }
            return;
        }
        var dt = previousNow == null ? 0.0 : (now - previousNow) / 1000.0;
        if (queued.indexOf(:END) != -1) { finish(sessionSec >= config[:goalSec]); return; }
        if (lifecycle == :ACTIVE && queued.indexOf(:PAUSE) != -1) {
            lifecycle = :PAUSED; resetDwell(); pipeline.reset(); previousNow = now; return;
        }
        if (lifecycle == :PAUSED) {
            previousNow = now;
            if (queued.indexOf(:RESUME) != -1) {
                lifecycle = :ACTIVE; pipeline.resetAfter(now); resetDwell();
                // Cached pre-resume readings must not qualify reacquisition.
                features = pipeline.update(Contracts.emptyFrame(now, mode, 0), now);
            }
            return;
        }
        if (dt <= 0) {
            // Preserve user events until the next positive tick.
            events = queued;
            return;
        }
        previousNow = now;
        if (dt > 2) { pipeline.reset(); resetDwell(); dt = 0.0; }
        features = pipeline.update(provider.snapshot(now), now);
        var remaining = config[:goalSec] - sessionSec;
        var credited = dt < remaining ? dt : remaining;
        sessionSec += credited;
        if (features[:movement] == :MOVING) { movingSec += credited; }
        if (features[:movement] == :UNKNOWN) { unknownMotionSec += credited; }
        if (features[:hrBpm] != null) { hrValidSec += credited; }
        if (sessionSec >= config[:goalSec]) { finish(true); return; }
        var event = queued.indexOf(:WALK_NOW) != -1 ? :WALK_NOW :
            (queued.indexOf(:ACCEPT_RUN) != -1 ? :ACCEPT_RUN : null);
        var old = memory[:advice];
        var result = engine.step(features, memory, dt, event);
        memory = result[:memory]; decision = result[:decision];
        if (old != memory[:advice]) {
            if (memory[:advice] == :WALK) { walkPromptCount++; }
            transitions.add({:at=>now / 1000, :advice=>memory[:advice]});
            if (transitions.size() > 32) { transitions = transitions.slice(1, transitions.size()); }
        }
    }
    function stop() { provider.stop(); }
}
