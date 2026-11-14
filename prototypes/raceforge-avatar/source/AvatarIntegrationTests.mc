import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:test)
function avatarWorkoutAndCoachAuthority(logger as Test.Logger) as Boolean {
    var adapter = new RaceForgeAvatarAdapter();
    var features = {:mode => :DEMO, :hrBpm => 160.0f, :hrReady => true,
                    :movement => :MOVING, :speedMps => 3.0f,
                    :sourceStatus => {:hr => :VALID, :speed => :VALID}};
    var decision = {:advice => :EASE_OFF, :decisionId => 42, :reason => :DEMO_SCRIPT, :canResumeRun => false};
    var easy = new RaceForgeAvatarWorkoutContext(:EASY_RUN, 120.0f, 145.0f);
    var tempo = new RaceForgeAvatarWorkoutContext(:TEMPO_RUN, 155.0f, 175.0f);
    easy.setDemoEffort(160.0f, 8000); tempo.setDemoEffort(160.0f, 8000);
    var model = adapter.fromContext(features, decision, :ACTIVE, easy, 1000);
    Test.assertEqual(model.visualState, :RUNNING_WINDED);
    Test.assertEqual(model.advice, :EASE_OFF);
    Test.assert(model.decisionId == 42);
    decision.put(:advice, :RUN_EASY);
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assertEqual(model.visualState, :RUNNING_HAPPY);
    Test.assertEqual(model.headline, "HOLD YOUR RHYTHM");
    model = adapter.fromContext(features, decision, :ACTIVE, easy, 1000);
    Test.assertEqual(model.visualState, :RUNNING_FOCUSED);
    Test.assertEqual(decision.get(:advice) as Symbol, :RUN_EASY);
    // No raw-HR classification in the normal live adapter.
    features.put(:mode, :LIVE); features.put(:hrBpm, 180.0f);
    model = adapter.fromPacePilot(features, decision, :ACTIVE, :EASY_RUN, 1000);
    Test.assertEqual(model.visualState, :RUNNING_HAPPY);
    easy.setDemoEffort(180.0f, 16000);
    model = adapter.fromContext(features, decision, :ACTIVE, easy, 1000);
    Test.assert(model.visualState != :RUNNING_EXHAUSTED);
    decision.put(:advice, :EASE_OFF);
    model = adapter.fromContext(features, decision, :ACTIVE, easy, 1000);
    Test.assertEqual(model.visualState, :RUNNING_EXHAUSTED);
    Test.assertEqual(model.flush, 2);
    Test.assertEqual(model.advice, :EASE_OFF); // never manufactures WALK
    easy.setDemoEffort(180.0f, 0);
    model = adapter.fromContext(features, decision, :ACTIVE, easy, 1000);
    Test.assertEqual(model.visualState, :RUNNING_WINDED);
    tempo.allowBuildEffort = true; tempo.setDemoEffort(130.0f, 8000);
    decision.put(:advice, :RUN_EASY);
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assertEqual(model.headline, "BUILD EFFORT");
    tempo.allowBuildEffort = false;
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assert(model.headline != "BUILD EFFORT");
    easy.upperBpm = 165.0f; easy.setDemoEffort(160.0f, 8000);
    Test.assertEqual(easy.effortBand, :TARGET);
    decision.put(:advice, :WALK);
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assertEqual(model.visualState, :WALKING); Test.assertEqual(model.motion, :WALK);
    decision.put(:advice, :READY_TO_RUN);
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assertEqual(model.visualState, :RECOVERING);
    decision.put(:canResumeRun, true);
    model = adapter.fromContext(features, decision, :ACTIVE, tempo, 1000);
    Test.assertEqual(model.visualState, :READY_TO_RUN); Test.assertEqual(model.readyLean, 2);
    logger.debug("160 easy vs tempo, configurable demo ranges, sustained expression, authoritative advice/resume");
    return true;
}

(:test)
function avatarUnavailableAndLifecycle(logger as Test.Logger) as Boolean {
    var adapter = new RaceForgeAvatarAdapter();
    var status = {:hr => :VALID, :speed => :VALID};
    var f = {:mode => :LIVE, :hrBpm => 180.0f, :hrReady => true, :movement => :MOVING,
             :speedMps => 3.0f, :sourceStatus => status};
    var d = {:advice => :EASE_OFF, :decisionId => 7, :canResumeRun => true};
    var invalid = [:STALE, :MISSING, :UNSUPPORTED, :ERROR, :UNKNOWN];
    for (var i = 0; i < invalid.size(); i += 1) {
        status.put(:hr, invalid[i]);
        var m = adapter.fromPacePilot(f, d, :ACTIVE, :EASY_RUN, 1000);
        Test.assertEqual(m.visualState, :SENSOR_UNAVAILABLE);
        Test.assertEqual(m.hrText, "HR --"); Test.assertEqual(m.flush, 0);
        Test.assert(!m.showSweat); Test.assertEqual(m.motion, :IDLE);
    }
    status.put(:hr, :VALID); f.put(:hrBpm, null);
    var model = adapter.fromPacePilot(f, d, :ACTIVE, :TEMPO_RUN, 1000);
    Test.assertEqual(model.hrText, "HR --");
    f.put(:hrBpm, 160.0f); f.put(:hrReady, false);
    model = adapter.fromPacePilot(f, d, :ACTIVE, :TEMPO_RUN, 1000);
    Test.assertEqual(model.visualState, :SENSOR_UNAVAILABLE);
    model = adapter.fromPacePilot(f, d, :PAUSED, :TEMPO_RUN, 1000);
    Test.assertEqual(model.visualState, :PAUSED); Test.assertEqual(model.frame, 0);
    model = adapter.fromPacePilot(f, d, :COMPLETE, :TEMPO_RUN, 1000);
    Test.assertEqual(model.visualState, :CELEBRATING);
    f.put(:hrReady, true); f.put(:movement, :STILL);
    model = adapter.fromPacePilot(f, d, :ACTIVE, :EASY_RUN, 1000);
    Test.assertEqual(model.motion, :IDLE); Test.assertEqual(model.frame, 0);
    Test.assertEqual(model.paceText, "PACE --");
    f.put(:movement, :UNKNOWN); status.put(:speed, :STALE);
    model = adapter.fromPacePilot(f, d, :ACTIVE, :EASY_RUN, 1000);
    Test.assert(model.speedMps == null); Test.assertEqual(model.movement, :UNKNOWN);
    f.put(:sourceStatus, {});
    model = adapter.fromPacePilot(f, d, :ACTIVE, :EASY_RUN, 1000);
    Test.assertEqual(model.visualState, :SENSOR_UNAVAILABLE);
    adapter.configureSourceKeys(:heartRate, :velocity);
    f.put(:sourceStatus, {:heartRate => :VALID, :velocity => :VALID});
    model = adapter.fromPacePilot(f, d, :ACTIVE, :EASY_RUN, 1000);
    Test.assertEqual(model.hrText, "HR 160");
    logger.debug("Null/not-ready/stale/error HR neutral; COMPLETE > PAUSED > missing; configurable source keys");
    return true;
}

(:test)
function avatarSpeedAndPlayback(logger as Test.Logger) as Boolean {
    var animator = new RaceForgeAvatarAnimator();
    var model = new RaceForgeAvatarModel(:JOG, "RUN", "HR 130", "DEMO");
    var fallback = animator.periodMs(model);
    Test.assert(fallback >= 900 && fallback <= 1800);
    model.speedMps = 2.0f; var slow = animator.periodMs(model);
    model.speedMps = 4.0f; var fast = animator.periodMs(model);
    Test.assert(fast < slow);
    model.speedMps = 1000000.0f;
    Test.assert(animator.periodMs(model) >= 900);
    model.motion = :WALK; Test.assert(animator.periodMs(model) > fast);
    model.movement = :STILL;
    animator.apply(model, 1200); Test.assertEqual(model.frame, 0);
    model.motion = :RUN; model.lifecycle = :PAUSED;
    animator.apply(model, 1200); Test.assertEqual(model.bob, 0);
    var demo = new RaceForgeAvatarDemoController();
    demo.setMode(:EASY_RUN); demo.advanceTime(8250);
    Test.assertEqual(demo.phase, 1); Test.assertEqual(demo.animationTime(), 250);
    demo.togglePause(); demo.advanceTime(20000);
    Test.assertEqual(demo.phase, 1); Test.assertEqual(demo.animationTime(), 250);
    demo.togglePause(); demo.advanceTime(250);
    Test.assertEqual(demo.animationTime(), 500);
    demo.advanceTime(1000000);
    Test.assertEqual(demo.phase, demo.count() - 1);
    Test.assertEqual(demo.getModel().visualState, :CELEBRATING);
    demo.setMode(:POSES); demo.advanceTime(10000);
    Test.assertEqual(demo.phase, 0);
    logger.debug("Nonlinear bounded speed response, walking default, still/paused, replay freeze and delayed ticks");
    return true;
}

(:test)
function avatarAllScenesAndCircularUi(logger as Test.Logger) as Boolean {
    var demo = new RaceForgeAvatarDemoController();
    var renderer = new RaceForgeAvatarRenderer();
    var view = new RaceForgeView();
    var ref = Graphics.createBufferedBitmap({:width => 260, :height => 260});
    var bitmap = ref.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    var modes = [:EASY_RUN, :TEMPO_RUN, :POSES];
    for (var k = 0; k < modes.size(); k += 1) {
        demo.setMode(modes[k]); view.setDemoMode(modes[k]);
        for (var scene = 0; scene < demo.count(); scene += 1) {
            var model = demo.getModel();
            Test.assertEqual(model.modeText, "DEMO");
            var font = view.headlineFont(dc, model.headline, 202);
            logger.debug(model.headline + " width=" + dc.getTextWidthInPixels(model.headline, font).toString() +
                         " height=" + dc.getFontHeight(font).toString());
            Test.assert(view.textFitsCircle(dc, model.headline, font, 202));
            Test.assert(202 + dc.getFontHeight(font) <= 228);
            Test.assert(view.textFitsCircle(dc, model.dataText, Graphics.FONT_XTINY, 180));
            Test.assert(view.textFitsCircle(dc, model.workoutText, Graphics.FONT_XTINY, 38));
            Test.assert(view.textFitsCircle(dc, demo.footer, Graphics.FONT_XTINY, 230));
            Test.assert(view.textFitsCircle(dc, "HOLD 10/10", Graphics.FONT_XTINY, 230));
            Test.assert(view.textFitsCircle(dc, "DEMO", Graphics.FONT_XTINY, 13));
            for (var frame = 0; frame < 4; frame += 1) {
                demo.advanceTime(250);
                renderer.draw(dc, demo.getModel(), 12, 24, 72, 84);
                renderer.draw(dc, demo.getModel(), 68, 57, 124, 124);
                view.onUpdate(dc);
            }
            demo.advance(); view.advanceDemo();
        }
    }
    view.onHide();
    logger.debug("All easy/tempo/static scenes render at two sizes; native font boxes fit the circle");
    return true;
}

(:test)
function avatarRenderingBudget(logger as Test.Logger) as Boolean {
    var animator = new RaceForgeAvatarAnimator();
    var renderer = new RaceForgeAvatarRenderer();
    var model = new RaceForgeAvatarModel(:EASE, "EASE OFF", "HR 160", "DEMO");
    model.visualState = :RUNNING_EXHAUSTED; model.flush = 2;
    var ref = Graphics.createBufferedBitmap({:width => 260, :height => 260});
    var bitmap = ref.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    for (var warm = 0; warm < 20; warm += 1) {
        animator.apply(model, warm * 250); renderer.draw(dc, model, 68, 57, 124, 124);
    }
    var before = System.getSystemStats().usedMemory;
    var started = System.getTimer();
    for (var i = 0; i < 600; i += 1) {
        animator.apply(model, i * 250);
        renderer.draw(dc, model, 68, 57, 124, 124);
    }
    var duration = System.getTimer() - started;
    var after = System.getSystemStats().usedMemory;
    Test.assert(after <= before + 4096);
    logger.debug("600 worst-expression renders: " + duration.toString() + "ms; retained memory before=" +
                 before.toString() + " after=" + after.toString() + " bytes (buffer included)");
    return true;
}
