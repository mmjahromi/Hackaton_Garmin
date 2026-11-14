import Toybox.Lang;

// Synthetic storyboards, not the team's 180-second coach replay or an HR engine.
// Default six static poses are retained for milestone-1 regression testing.
class RaceForgeAvatarDemoController {
    var phase as Number = 0;
    var mode as Symbol = :POSES;
    var paused as Boolean = false;
    var footer as String = "POSES 1/6";
    private var _models as Array<RaceForgeAvatarModel>;
    private var _phaseTime as Number = 0;
    private var _animator as RaceForgeAvatarAnimator;
    private var _adapter as RaceForgeAvatarAdapter;
    const PHASE_MS = 8000;

    function initialize() {
        _animator = new RaceForgeAvatarAnimator();
        _adapter = new RaceForgeAvatarAdapter();
        _models = [];
        setMode(:POSES);
    }

    function setMode(value as Symbol) as Void {
        mode = value; phase = 0; _phaseTime = 0; paused = false;
        if (mode == :POSES) {
            _models = [
                new RaceForgeAvatarModel(:IDLE, "START MISSION", "HR --", "DEMO"),
                new RaceForgeAvatarModel(:JOG, "NICE & EASY", "HR 130", "DEMO"),
                new RaceForgeAvatarModel(:EASE, "EASE OFF", "HR 150", "DEMO"),
                new RaceForgeAvatarModel(:WALK, "WALK BREAK", "HR 130", "DEMO"),
                new RaceForgeAvatarModel(:RECOVER, "READY? YOUR CHOICE", "HR 130", "DEMO"),
                new RaceForgeAvatarModel(:CELEBRATE, "MISSION COMPLETE", "HR --", "DEMO")
            ];
        } else if (mode == :TEMPO_RUN) {
            _models = [
                sample(:TEMPO_RUN, 130.0f, 2.3f, :RUN_EASY, :ACTIVE, false, 8000),
                sample(:TEMPO_RUN, 155.0f, 3.1f, :RUN_EASY, :ACTIVE, false, 8000),
                sample(:TEMPO_RUN, 160.0f, 3.5f, :RUN_EASY, :ACTIVE, false, 8000),
                sample(:TEMPO_RUN, 180.0f, 3.0f, :EASE_OFF, :ACTIVE, false, 8000),
                sample(:TEMPO_RUN, null, null, :RUN_EASY, :COMPLETE, false, 0)
            ];
        } else {
            mode = :EASY_RUN;
            _models = [
                sample(:EASY_RUN, null, null, :RUN_EASY, :READY, false, 0),
                sample(:EASY_RUN, 130.0f, 2.5f, :RUN_EASY, :ACTIVE, false, 8000),
                sample(:EASY_RUN, 160.0f, 2.8f, :RUN_EASY, :ACTIVE, false, 0),
                sample(:EASY_RUN, 160.0f, 2.3f, :EASE_OFF, :ACTIVE, false, 8000),
                sample(:EASY_RUN, 180.0f, 2.0f, :EASE_OFF, :ACTIVE, false, 16000),
                sample(:WALK, 130.0f, 1.2f, :WALK, :ACTIVE, false, 8000),
                sample(:REST, 130.0f, 0.0f, :READY_TO_RUN, :ACTIVE, false, 8000),
                sample(:EASY_RUN, 130.0f, 0.0f, :READY_TO_RUN, :ACTIVE, true, 8000),
                sample(:EASY_RUN, null, null, :RUN_EASY, :ACTIVE, false, 0),
                sample(:EASY_RUN, null, null, :RUN_EASY, :COMPLETE, false, 0)
            ];
        }
        for (var i = 0; i < _models.size(); i += 1) { _models[i].decisionId = i; }
        updateFooter();
    }

    function advance() as Void {
        phase = (phase + 1) % _models.size();
        _phaseTime = 0;
        updateFooter();
    }

    function advanceTime(deltaMs as Number) as Void {
        if (paused || mode == :POSES || deltaMs <= 0) { return; }
        // Bound arithmetic even after a very delayed callback. O(1), no catch-up loop.
        var delta = deltaMs > PHASE_MS * _models.size() ? PHASE_MS * _models.size() : deltaMs;
        var position = phase * PHASE_MS + _phaseTime + delta;
        var finalTime = _models.size() * PHASE_MS - 1;
        if (position > finalTime) { position = finalTime; }
        var nextPhase = position / PHASE_MS;
        _phaseTime = position % PHASE_MS;
        if (nextPhase != phase) { phase = nextPhase; updateFooter(); }
    }

    function togglePause() as Void { paused = !paused; updateFooter(); }
    function animationTime() as Number { return _phaseTime; }
    function count() as Number { return _models.size(); }
    function isFinished() as Boolean {
        return mode != :POSES && phase == _models.size() - 1 &&
               _models[phase].visualState == :CELEBRATING && _phaseTime >= 2400;
    }

    function getModel() as RaceForgeAvatarModel {
        var model = _models[phase];
        if (mode != :POSES) { _animator.apply(model, _phaseTime); }
        return model;
    }

    private function updateFooter() as Void {
        footer = (paused ? "HOLD " : (mode == :POSES ? "S " : (mode == :TEMPO_RUN ? "T " : "E "))) +
                 (phase + 1).toString() + "/" + _models.size().toString();
    }

    private function sample(workout as Symbol, hr as Float?, speed as Float?,
                            advice as Symbol, lifecycle as Symbol, resume as Boolean,
                            sustainedMs as Number) as RaceForgeAvatarModel {
        var context = new RaceForgeAvatarWorkoutContext(workout,
                          workout == :TEMPO_RUN ? 155.0f : 120.0f,
                          workout == :TEMPO_RUN ? 175.0f : 145.0f);
        context.allowBuildEffort = workout == :TEMPO_RUN;
        context.setDemoEffort(hr, sustainedMs);
        var features = {:mode => :DEMO, :hrBpm => hr, :hrReady => hr != null,
                        :speedMps => speed, :movement => speed == 0.0f ? :STILL : :MOVING,
                        :sourceStatus => {:hr => hr == null ? :MISSING : :VALID, :speed => :VALID}};
        var decision = {:advice => advice, :reason => :DEMO_SCRIPT,
                        :decisionId => _models.size(), :canResumeRun => resume};
        return _adapter.fromContext(features, decision, lifecycle, context, 0);
    }
}
