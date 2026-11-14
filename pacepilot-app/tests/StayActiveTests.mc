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
