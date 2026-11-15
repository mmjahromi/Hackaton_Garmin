import Toybox.Lang;
import Toybox.Test;

// Home screen, short start, and "Get today's plan".

(:test)
function homeStartsInTwoPresses(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults(); v.mode = :DEMO;
    var dc = new DrawingProbe();
    Test.assert(v.stage == -1 && v.ready());
    Presenter.render(dc, v);
    v.adjust(1);                       // UP/DOWN do nothing on the home screen
    Test.assert(v.stage == -1 && v.mode == :DEMO);
    v.select();                        // START -> review
    Test.assert(v.stage == 8 && v.quick && v.ready());
    Presenter.render(dc, v);
    v.select();                        // START -> workout begins
    Test.assert(v.controller.lifecycle == :ACTIVE);
    v.shutdown();
    return true;
}

(:test)
function backFromReviewReturnsHome(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    v.select();
    Test.assert(v.stage == 8);
    Test.assert(v.back() && v.stage == -1);
    v.task(:setup);                    // menu: Change settings
    Test.assert(v.stage == 0 && !v.quick);
    v.back();
    Test.assert(v.stage == -1);
    v.shutdown();
    return true;
}

(:test)
function planOfferParsesAGoodAnswer(logger as Logger) as Boolean {
    var offer = PlanOffer.parse(200, {"available" => true, "suggestion" =>
        {"id" => "stay_active:real:2026-11-14", "kind" => "workout", "activity" => "walk",
         "durationMin" => 15, "reason" => "Restart with a shorter session."}});
    return offer[:ok] && offer[:text].equals("15 min walk") && offer[:goalSec] == 900 &&
        offer[:id].equals("stay_active:real:2026-11-14");
}

(:test)
function planOfferRefusesAnythingElse(logger as Logger) as Boolean {
    var good = {"id" => "x", "kind" => "workout", "activity" => "walk", "durationMin" => 15, "reason" => "r"};
    Test.assert(!PlanOffer.parse(500, {"available" => true, "suggestion" => good})[:ok]);
    Test.assert(!PlanOffer.parse(200, null)[:ok]);
    Test.assert(!PlanOffer.parse(200, "text")[:ok]);
    Test.assert(!PlanOffer.parse(200, {"available" => false})[:ok]);
    Test.assert(!PlanOffer.parse(200, {"available" => true})[:ok]);
    Test.assert(!PlanOffer.parse(200, {"available" => true, "suggestion" =>
        {"id" => "x", "kind" => "rest", "durationMin" => 0, "reason" => "Rest today."}})[:ok]);
    Test.assert(!PlanOffer.parse(200, {"available" => true, "suggestion" =>
        {"id" => "x", "kind" => "workout", "activity" => "walk", "durationMin" => 500}})[:ok]);
    Test.assert(!PlanOffer.parse(200, {"available" => true, "suggestion" =>
        {"kind" => "workout", "activity" => "walk", "durationMin" => "15"}})[:ok]);
    return true;
}

(:test)
function planChangesNothingUntilAccepted(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    var before = v.config[:goalSec];
    var dc = new DrawingProbe();
    v.planScreen = PlanOffer.waiting();
    Presenter.render(dc, v);
    v.onPlan(200, {"available" => true, "suggestion" =>
        {"id" => "p1", "kind" => "workout", "activity" => "run_walk", "durationMin" => 12, "reason" => "A short restart after two missed days."}});
    Presenter.render(dc, v);
    Test.assert(v.planGoalSec == null && v.planId == null && v.config[:goalSec] == before);
    v.back();                          // BACK keeps the user's own goal
    Test.assert(v.planScreen == null && v.planGoalSec == null);
    v.planScreen = PlanOffer.waiting();
    v.onPlan(200, {"available" => true, "suggestion" =>
        {"id" => "p1", "kind" => "workout", "activity" => "run_walk", "durationMin" => 12, "reason" => "r"}});
    v.select();                        // START uses it, then shows the review screen
    Test.assert(v.planGoalSec == 720 && v.planId.equals("p1") && v.stage == 8 && v.controller == null);
    Test.assert(v.config[:goalSec] == before);   // the saved goal is untouched
    v.shutdown();
    return true;
}

(:test)
function lateOrFailedPlanAnswerIsHarmless(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    v.onPlan(200, {"available" => true});          // user already left the screen
    Test.assert(v.planScreen == null);
    v.planScreen = PlanOffer.waiting();
    v.onPlan(-104, null);                          // no answer: no demo retry either
    Test.assert(!v.planScreen[:ok]);
    v.select();                                    // START on a failure just closes it
    Test.assert(v.planScreen == null && v.planGoalSec == null && v.stage == -1);
    v.shutdown();
    return true;
}

(:test)
function wrapSplitsAtWords(logger as Logger) as Boolean {
    var two = PlanOffer.wrap("Restart with a shorter session after missing planned days.", 24);
    Test.assert(two[0].equals("Restart with a shorter") && two[1].length() <= 24);
    var one = PlanOffer.wrap("Short", 24);
    return one[0].equals("Short") && one[1].equals("") && PlanOffer.wrap(null, 24)[0].equals("");
}

(:test)
function demoPlanIsLabelledAndNeverReported(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    v.planScreen = {:ok => false, :text => "x", :detail => "y"};   // not the waiting screen: no network in tests
    v.onPlan(200, {"available" => true, "demo" => true, "suggestion" =>
        {"id" => "stay_active:demo:2026-11-14", "kind" => "workout", "activity" => "run_walk", "durationMin" => 15, "reason" => "r"}});
    Test.assert(v.planScreen[:ok] && v.planScreen[:demo] && v.planScreen[:text].equals("Demo: 15 min run/walk"));
    Presenter.render(new DrawingProbe(), v);
    v.select();
    Test.assert(v.planGoalSec == 900 && v.planDemo && v.planId == null);
    v.shutdown();
    return true;
}

(:test)
function sharingOffAnswerDoesNotLoopInTests(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    v.planScreen = {:ok => false, :text => "x", :detail => "y"};
    v.onPlan(200, {"available" => false});
    Test.assert(!v.planScreen[:ok] && v.planScreen[:text].equals("Plan sharing is off"));
    v.shutdown();
    return true;
}

(:test)
function reviewScreenTogglesSharing(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults(); v.mode = :DEMO;
    var dc = new DrawingProbe();
    v.adjust(1);                          // home: no effect
    Test.assert(!v.share);
    v.select();                           // review
    Test.assert(!v.share);                // off by default, every session
    v.adjust(1); Presenter.render(dc, v);
    Test.assert(v.share);
    v.adjust(-1); Presenter.render(dc, v);
    Test.assert(!v.share);
    v.adjust(1);
    v.select();                           // begin with sharing on
    Test.assert(v.controller.lifecycle == :ACTIVE && v.share);
    v.shutdown();
    return true;
}

(:test)
function appOpensOnActivateScreen(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults();
    v.activated = false; v.autoLink = false;      // as the app launches it, minus the network call
    var dc = new DrawingProbe();
    Presenter.render(dc, v);
    Test.assert(dc.texts.indexOf("START to open") != -1);
    v.adjust(1); v.menu();                        // nothing else responds yet
    Test.assert(!v.activated && v.stage == -1);
    v.select();                                   // START opens the app
    Test.assert(v.activated && v.stage == -1 && v.controller == null);
    Presenter.render(dc, v);
    Test.assert(dc.texts.indexOf("START to open") == -1);
    v.shutdown();
    return true;
}

(:test)
function backOnActivateScreenExits(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.activated = false; v.autoLink = false;
    return !v.back();
}

(:test)
function drinkCueRules(logger as Logger) as Boolean {
    Test.assert(Fuel.intervalSec(0, 1200) == 0);        // auto: a 20-minute session gets no cue
    Test.assert(Fuel.intervalSec(0, 2700) == 900);      // auto: 45 minutes or more, every 15
    Test.assert(Fuel.intervalSec(1, 7200) == 0);        // off stays off
    Test.assert(Fuel.intervalSec(2, 600) == 600 && Fuel.intervalSec(4, 600) == 1200);
    Test.assert(!Fuel.due(899, 0, 900) && Fuel.due(900, 0, 900));
    Test.assert(!Fuel.due(1500, 900, 900) && Fuel.due(1800, 900, 900));
    return !Fuel.due(99999, 0, 0);                      // no interval, never due
}

(:test)
function loggingFoodAndDrinkKeepsTheWorkoutRunning(logger as Logger) as Boolean {
    var v = new PacePilotView();
    v.config = Config.defaults(); v.mode = :DEMO; v.stage = 8;
    v.select();
    Test.assert(v.controller.lifecycle == :ACTIVE && v.fluidMl == 0 && v.carbsG == 0);
    v.drinkDue = true;
    v.task(:drink);
    Test.assert(v.fluidMl == 150 && !v.drinkDue && v.controller.lifecycle == :ACTIVE);
    v.task(:food); v.task(:food);
    Test.assert(v.carbsG == 50 && v.controller.lifecycle == :ACTIVE);
    Presenter.render(new DrawingProbe(), v);
    v.metricsPage = true; Presenter.render(new DrawingProbe(), v);
    v.shutdown();
    return true;
}

(:test)
function drinkReminderSettingCycles(logger as Logger) as Boolean {
    var v = new PacePilotView();
    for (var i = 0; i < 5; i++) { Test.assert(Fuel.modeLabel(v.drinkMode) instanceof Toybox.Lang.String); v.task(:drinkmode); }
    Test.assert(v.drinkMode == 0);
    v.shutdown();
    return true;
}

(:test)
function effortMeterCountsOnlyMovingSecondsWithHeartRate(logger as Logger) as Boolean {
    var m = new EffortMeter();
    Test.assert(m.avgHr() == null && m.avgSpeedMps() == null);
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => 120, :speedMps => 1.5});
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => 130, :speedMps => 1.7});
    m.add(:PAUSED, {:hrReady => true, :hrBpm => 200, :speedMps => 1.6});    // paused
    m.add(:ACTIVE, {:hrReady => false, :hrBpm => 200, :speedMps => 1.6});   // reading not ready
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => null, :speedMps => 1.6});   // no heart rate
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => 200, :speedMps => null});   // no speed
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => 200, :speedMps => 0.2});    // standing
    m.add(:ACTIVE, {:hrReady => true, :hrBpm => 200, :speedMps => 30.0});   // GPS glitch
    m.add(:ACTIVE, null);
    Test.assert(m.seconds == 2 && m.avgHr() == 125);
    var speed = m.avgSpeedMps();
    return speed > 1.59 && speed < 1.61;
}
