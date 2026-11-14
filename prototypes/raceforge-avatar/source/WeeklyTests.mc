import Toybox.Lang;
import Toybox.Test;
import Toybox.Application;
import Toybox.Graphics;

(:test)
class RaceForgeTestStorage {
    var value=null; var fail=false; var writes=0;
    function initialize() {}
    function read(key) { return RaceForgeJourneyData.copy(value); }
    function write(key,data) {
        if(fail) { throw new Lang.Exception(); }
        value=RaceForgeJourneyData.copy(data); writes+=1;
    }
}
(:test)
module RaceForgeWeeklyFixtures {
    function result(id,goal) { return {"sessionId"=>id,"mode"=>"LIVE","goalMet"=>goal,
        "elapsedSec"=>300.0,"movingSec"=>0.0,"unknownMotionSec"=>300.0}; }
    function flow() {
        var f=new RaceForgeAdventureController();
        var repo=new RaceForgeJourneyRepository(new RaceForgeTestStorage()); f.restore(repo);
        for(var i=0;i<4;i+=1) { f.select(); } return f;
    }
}

(:test)
function weeklyPlanTemplates(logger as Test.Logger) as Boolean {
    for(var level=0;level<3;level+=1) {
        for(var days=3;days<=5;days+=1) {
            for(var time=0;time<3;time+=1) {
                var d=RaceForgeWeeklyPlan.generate({"level"=>level,"days"=>days,"activity"=>0,"time"=>time});
                Test.assert(RaceForgeJourneyData.valid(d));
                Test.assertEqual(d["missions"].size(),days==3 ? 4 : 5);
                Test.assert(d["missions"][0]["activityType"].equals("walk"));
                Test.assert(d["missions"][1]["optional"]);
                Test.assert(d["missions"][2]["durationTargetSec"]<=d["missions"][0]["durationTargetSec"]);
            }
        }
    }
    Test.assert(!RaceForgeWeeklyPlan.validProfile({"level"=>0.5,"days"=>3,"activity"=>0,"time"=>0}));
    logger.debug("27 level/day/time templates: 4-5 actual checkpoints, gentle short beginner missions");
    return true;
}

(:test)
function weeklyCompletionAndAdjustments(logger as Test.Logger) as Boolean {
    var d=RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()); var j=new RaceForgeWeeklyJourney(d);
    Test.assert(j.finish(0,RaceForgeWeeklyFixtures.result(1,true)));
    Test.assert(!j.finish(0,RaceForgeWeeklyFixtures.result(1,true)));
    Test.assert(!j.finish(2,RaceForgeWeeklyFixtures.result(2,true)));
    Test.assertEqual(j.completed(),1);
    var proposal=RaceForgePlanChanges.propose(j,1,"shorten");
    var duration=j.missions()[1]["durationTargetSec"];
    Test.assertEqual(proposal["duration"] as Number,duration/2);
    Test.assertEqual(j.missions()[1]["durationTargetSec"] as Number,duration);
    Test.assert(RaceForgePlanChanges.confirm(j,proposal));
    Test.assert(!RaceForgePlanChanges.confirm(j,proposal));
    Test.assertEqual(j.completed(),1); Test.assertEqual(j.data["position"] as Number,0);
    var missed=RaceForgePlanChanges.propose(j,1,"missed");
    Test.assert(RaceForgePlanChanges.confirm(j,missed));
    Test.assert(j.missions()[1]["status"].equals("missed"));
    var skip=RaceForgePlanChanges.propose(j,1,"skip");
    Test.assert(RaceForgePlanChanges.confirm(j,skip));
    Test.assertEqual(j.data["position"] as Number,0);
    Test.assert(j.finish(2,RaceForgeWeeklyFixtures.result(2,true)));
    Test.assert(j.finish(3,RaceForgeWeeklyFixtures.result(3,true)));
    Test.assertEqual(j.completed(),3); Test.assert(j.isComplete()); // skipped checkpoint is not fabricated completion
    Test.assertEqual(j.data["position"] as Number,3);
    Test.assert(RaceForgeJourneyData.valid(j.data));
    var longProfile=RaceForgeWeeklyPlan.defaults(); longProfile["days"]=5;
    var moving=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(longProfile));
    var move=RaceForgePlanChanges.propose(moving,0,"move");
    Test.assert(move["allowed"]); Test.assertEqual(move["day"] as Number,7);
    Test.assertEqual(moving.missions()[0]["plannedDay"] as Number,1);
    Test.assert(RaceForgePlanChanges.confirm(moving,move));
    Test.assertEqual(moving.missions()[moving.missions().size()-2]["plannedDay"] as Number,7);
    Test.assert(moving.missions()[0]["missionId"].equals("week-2"));
    Test.assertEqual(moving.data["position"] as Number,-1);
    logger.debug("Explicit completion only, duplicate/stale proposals rejected, missed/skip preserve achievements, free-day move");
    return true;
}

(:test)
function weeklyPersistenceAndSafeDefaults(logger as Test.Logger) as Boolean {
    var port=new RaceForgeTestStorage(); var repo=new RaceForgeJourneyRepository(port);
    var j=repo.load(); j.data["configured"]=true;
    Test.assert(j.finish(0,RaceForgeWeeklyFixtures.result(1,true)));
    Test.assert(repo.save(j));
    j.data["position"]=-1; // storage copies, rather than retaining mutable references
    var restarted=new RaceForgeJourneyRepository(port).load();
    Test.assertEqual(restarted.completed(),1); Test.assertEqual(restarted.data["position"] as Number,0);
    port.value={"schemaVersion"=>99}; var unknown=new RaceForgeJourneyRepository(port);
    var fallback=unknown.load(); Test.assertEqual(fallback.completed(),0);
    Test.assert(!unknown.writable); Test.assert(!unknown.save(fallback));
    Test.assertEqual(port.value["schemaVersion"] as Number,99);
    var invalid=RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()); invalid["missions"]=[];
    Test.assert(!RaceForgeJourneyData.valid(invalid));
    var bounded=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()));
    for(var i=1;i<=20;i+=1) { bounded.finish(0,RaceForgeWeeklyFixtures.result(i,false)); }
    Test.assertEqual(bounded.data["history"].size(),8);
    Test.assertEqual(bounded.completed(),0);
    Test.assert(!bounded.finish(0,RaceForgeWeeklyFixtures.result(1,true)));
    logger.debug("Restart restores checkpoints, corrupt/new schemas preserved, histories bounded to 8, partials never advance");
    return true;
}

(:test)
function weeklyNativeStorageRestart(logger as Test.Logger) as Boolean {
    // Dedicated test key; never write or delete the real user's journey key.
    var key="raceforge.test.weekly.v1";
    var port=new RaceForgeStoragePort(); var previous=port.read(key);
    var repository=new RaceForgeJourneyRepository(port); repository.key=key;
    var j=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()));
    j.data["configured"]=true; j.finish(0,RaceForgeWeeklyFixtures.result(5,true));
    for(var history=6;history<=20;history+=1) { j.finish(1,RaceForgeWeeklyFixtures.result(history,false)); }
    for(var change=0;change<16;change+=1) { RaceForgePlanChanges.confirm(j,RaceForgePlanChanges.propose(j,1,"missed")); }
    Test.assertEqual(j.data["history"].size(),8); Test.assertEqual(j.data["adjustments"].size(),12);
    var saved=repository.save(j);
    var restarted=new RaceForgeJourneyRepository(port); restarted.key=key; var restored=restarted.load();
    // Restore the test namespace before assertions, including on a failed read.
    if(previous==null) { Application.Storage.deleteValue(key); } else { port.write(key,previous); }
    Test.assert(saved); Test.assertEqual(restored.completed(),1);
    Test.assertEqual(restored.data["position"] as Number,0);
    logger.debug("Real Application.Storage serializes/reloads versioned string-key records (isolated test key)");
    return true;
}

(:test)
function weeklyDemoSeparationAndSaveFailure(logger as Test.Logger) as Boolean {
    var flow=RaceForgeWeeklyFixtures.flow(); var port=flow.repository.port;
    var initialWrites=port.writes;
    flow.select(); flow.select(); flow.select();
    for(var i=0;i<180;i+=1) { flow.step(250); }
    Test.assertEqual(flow.screen,:SUMMARY);
    flow.commitResult();
    Test.assertEqual(flow.journey.completed(),1); Test.assertEqual(flow.liveJourney.completed(),0);
    Test.assertEqual(port.writes,initialWrites);
    flow.setMode(:LIVE); Test.assertEqual(flow.journey.completed(),0);
    // Inject a completed DEMO-controlled session as a pending LIVE result to test
    // transactional storage failure without acquiring sensors or faking readings.
    var m=flow.journey.missions()[0]; flow.session=new RaceForgeSessionBridge(m,:DEMO,1);
    for(var t=0;t<180;t+=1) { flow.session.step(250); }
    flow.session.mode=:LIVE; flow.screen=:SUMMARY;
    port.fail=true;
    Test.assert(!flow.commitResult()); Test.assertEqual(flow.journey.completed(),0);
    Test.assert(flow.session!=null);
    port.fail=false; Test.assert(flow.commitResult());
    Test.assertEqual(flow.journey.completed(),1);
    var restart=new RaceForgeAdventureController(); restart.restore(new RaceForgeJourneyRepository(port));
    Test.assertEqual(restart.mode,:LIVE); Test.assertEqual(restart.journey.completed(),1);
    restart.finishSetup(); Test.assertEqual(restart.journey.completed(),1);
    logger.debug("DEMO cannot write real progress; failed LIVE save rolls back, retry and restart preserve checkpoint");
    return true;
}

(:test)
function weeklySharedCoachingAndMissingData(logger as Test.Logger) as Boolean {
    var mission=RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults())["missions"][0];
    var session=new RaceForgeSessionBridge(mission,:DEMO,1);
    var sawEase=false; var sawWalk=false; var sawReady=false;
    for(var i=0;i<179;i+=1) {
        session.step(250); var advice=session.controller.decision[:advice];
        if(advice==:EASE_OFF) { sawEase=true; }
        if(advice==:WALK) { sawWalk=true; Test.assertEqual(session.avatar.motion,:WALK); }
        if(advice==:READY_TO_RUN) { sawReady=true; Test.assert(session.controller.decision[:canResumeRun]); }
    }
    Test.assert(sawEase && sawWalk && sawReady);
    var elapsed=session.controller.sessionSec;
    session.event(:PAUSE); session.step(250);
    Test.assertEqual(session.controller.sessionSec,elapsed);
    Test.assertEqual(session.avatar.visualState,:PAUSED); Test.assert(session.avatar.hrText.equals("HR --"));
    session.event(:RESUME); session.step(250);
    var loss=new RaceForgeSessionBridge(mission,:DEMO,2);
    loss.controller.provider.stop(); loss.controller.provider=new ReplayProvider(:TOTAL_LOSS); loss.controller.provider.start();
    for(var k=0;k<20;k+=1) { loss.step(250); }
    Test.assertEqual(loss.avatar.visualState,:SENSOR_UNAVAILABLE);
    Test.assertEqual(loss.controller.movingSec,0.0);
    Test.assert(loss.controller.unknownMotionSec>0.0);
    loss.controller.dispatch(:WALK_NOW); loss.step(250);
    Test.assertEqual(loss.controller.decision[:advice] as Symbol,:WALK);
    Test.assertEqual(loss.avatar.visualState,:SENSOR_UNAVAILABLE);
    logger.debug("Actual PacePilot engine drives ease/walk/ready; pause freezes time, missing motion is unknown, HR loss stays neutral");
    return true;
}

(:test)
function weeklyPaceAndLiveLifecycle(logger as Test.Logger) as Boolean {
    var adapter=new RaceForgeAvatarAdapter();
    var f={:mode=>:LIVE,:hrBpm=>130.0f,:hrReady=>true,:speedMps=>2.5f,:movement=>:MOVING,
        :sourceStatus=>{:hr=>:VALID,:speed=>:VALID}};
    var d={:advice=>:RUN_EASY,:decisionId=>1,:canResumeRun=>false};
    var m=adapter.fromPacePilot(f,d,:ACTIVE,:EASY_RUN,1000);
    Test.assert(m.paceText.equals("6:40/km")); Test.assert(m.modeText.equals("LIVE"));
    f[:speedMps]=0.0f; m=adapter.fromPacePilot(f,d,:ACTIVE,:EASY_RUN,1000); Test.assert(m.paceText.equals("PACE --"));
    f[:speedMps]=-1.0f; m=adapter.fromPacePilot(f,d,:ACTIVE,:EASY_RUN,1000); Test.assert(m.speedMps==null);
    f[:sourceStatus][:hr]=:STALE; m=adapter.fromPacePilot(f,d,:ACTIVE,:EASY_RUN,1000);
    Test.assertEqual(m.visualState,:SENSOR_UNAVAILABLE);
    // API-path simulator smoke test, not proof of physical heart-rate or GPS.
    var live=new RaceForgeLiveProvider(); live.start(); var origin=live.origin;
    Test.assert(live.running); var snapshot=live.snapshot(live.now()); Test.assertEqual(snapshot[:mode] as Symbol,:LIVE);
    live.stop(); Test.assert(!live.sensorOwned && !live.accelOwned && !live.positionOwned);
    live.start(); var preserved=live.origin==origin; live.stop(); Test.assert(preserved);
    var mission=RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults())["missions"][0];
    var liveSession=new RaceForgeSessionBridge(mission,:LIVE,99);
    liveSession.event(:PAUSE); var pausedSec=liveSession.controller.sessionSec;
    Test.assert(!liveSession.controller.provider.running);
    liveSession.step(250); Test.assertEqual(liveSession.controller.sessionSec,pausedSec);
    liveSession.event(:RESUME); Test.assert(liveSession.controller.provider.running);
    Test.assert(!liveSession.controller.features[:hrReady]);
    liveSession.event(:END); Test.assertEqual(liveSession.controller.lifecycle,:COMPLETE);
    Test.assert(!liveSession.controller.provider.sensorOwned); liveSession.stop();
    var gate=new AlertGate(); Test.assert(gate.allow(1,0)); Test.assert(!gate.allow(1,15000)); Test.assert(!gate.allow(2,1000));
    logger.debug("Pace zero/invalid safe; stale HR neutral; shared LIVE provider start/stop/restart API path and haptic dedup gate");
    return true;
}

(:test)
function weeklySetupCheckinsAndScreens(logger as Test.Logger) as Boolean {
    var view=new RaceForgeAdventureView(); view.flow=new RaceForgeAdventureController();
    var ref=Graphics.createBufferedBitmap({:width=>260,:height=>260}); var bitmap=ref.get() as Graphics.BufferedBitmap;
    var dc=bitmap.getDc();
    for(var setup=0;setup<4;setup+=1) { view.onUpdate(dc); Test.assert(view.layoutValid); view.flow.select(); }
    view.onUpdate(dc); Test.assert(view.layoutValid);
    view.flow.menu(); view.onUpdate(dc); view.flow.select(); view.onUpdate(dc); view.flow.select();
    view.flow.select(); view.onUpdate(dc); view.flow.select(); view.onUpdate(dc);
    view.flow.move(1); view.onUpdate(dc); view.flow.select();
    view.flow.menu(); view.onUpdate(dc); view.flow.move(2); view.flow.select(); view.onUpdate(dc); view.flow.back();
    view.flow.screen=:PREVIEW; view.flow.select();
    for(var i=0;i<180;i+=1) { view.flow.step(250); }
    view.onUpdate(dc); Test.assert(view.layoutValid);
    view.flow.select(); Test.assertEqual(view.flow.screen,:CHECKIN);
    for(var q=0;q<3;q+=1) { view.onUpdate(dc); Test.assert(view.layoutValid); view.flow.select(); }
    Test.assertEqual(view.flow.journey.completed(),1);
    Test.assertEqual(view.flow.journey.data["history"][0]["effort"] as Number,1);
    view.onHide();
    logger.debug("Setup, options, source, band, adjustments, workout/summary and local check-ins fit measured circular text bounds");
    return true;
}

(:test)
function weeklyAdventureLifecycleAndWeekFinish(logger as Test.Logger) as Boolean {
    var view=new RaceForgeAdventureView(); view.flow=RaceForgeWeeklyFixtures.flow();
    view.onShow(); view.onShow(); Test.assert(!view._running);
    view.pressSelect(); view.pressSelect(); view.pressSelect(); Test.assert(view._running);
    view.flow.step(250); view.onHide();
    var paused=view.flow.session.controller.sessionSec;
    Test.assertEqual(view.flow.screen,:PAUSE); Test.assert(!view._running);
    view.onTick(); Test.assertEqual(view.flow.session.controller.sessionSec,paused);
    view.onShow(); Test.assert(!view._running); view.pressSelect(); Test.assert(view._running);
    view.onHide(); view.shutdown();
    var flow=RaceForgeWeeklyFixtures.flow();
    var count=flow.journey.missions().size();
    for(var mission=0;mission<count-1;mission+=1) {
        flow.select(); flow.select(); flow.select();
        for(var tick=0;tick<180;tick+=1) { flow.step(250); }
        Test.assertEqual(flow.screen,:SUMMARY); Test.assert(flow.commitResult());
        Test.assertEqual(flow.journey.completed(),mission+1);
    }
    Test.assert(!flow.journey.isComplete());
    flow.select(); flow.select(); flow.select(); // final weekly check-in, not an extra workout
    Test.assert(flow.journey.isComplete()); Test.assertEqual(flow.journey.data["position"] as Number,count-1);
    var position=flow.journey.data["position"];
    for(var idle=0;idle<30;idle+=1) { flow.step(1000); }
    Test.assertEqual(flow.journey.data["position"] as Number,position);
    logger.debug("Adventure timer stops on hide and pauses safely; all missions and explicit summit check-in finish week without time-driven movement");
    return true;
}

(:test)
function weeklyPhysicalButtonDelegate(logger as Test.Logger) as Boolean {
    var view=new RaceForgeAdventureView(); view.flow=RaceForgeWeeklyFixtures.flow();
    var delegate=new RaceForgeAdventureDelegate(view); view.onShow();
    Test.assert(!delegate.onBack());
    delegate.onMenu(); Test.assertEqual(view.flow.screen,:OPTIONS);
    delegate.onSelect(); Test.assertEqual(view.flow.screen,:SOURCE);
    delegate.onSelect(); Test.assertEqual(view.flow.screen,:HOME);
    delegate.onSelect(); Test.assertEqual(view.flow.screen,:LIST);
    delegate.onNextPage(); Test.assertEqual(view.flow.selected,1);
    delegate.onPreviousPage(); Test.assertEqual(view.flow.selected,0);
    delegate.onSelect(); delegate.onSelect(); Test.assertEqual(view.flow.screen,:WORKOUT);
    view.flow.step(250); delegate.onNextPage(); view.flow.step(250);
    Test.assertEqual(view.flow.session.controller.decision[:advice] as Symbol,:WALK);
    delegate.onSelect(); Test.assertEqual(view.flow.screen,:PAUSE); Test.assert(!view._running);
    delegate.onBack(); Test.assertEqual(view.flow.screen,:END_CONFIRM);
    delegate.onNextPage(); delegate.onSelect(); Test.assertEqual(view.flow.screen,:SUMMARY);
    delegate.onMenu(); Test.assertEqual(view.flow.screen,:HOME);
    Test.assertEqual(view.flow.journey.completed(),0); view.shutdown();
    logger.debug("Actual BehaviorDelegate START/UP/DOWN/BACK/MENU callbacks navigate, pause, walk, confirm end and save partial without progress");
    return true;
}
