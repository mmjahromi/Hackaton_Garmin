import Toybox.Test;
import Toybox.Lang;
(:test)
function weeklyEntryUsesExistingPacePilot(logger as Logger) as Boolean {
    var v=new PacePilotView();
    v.task(:missions);
    Test.assert(v.stage==9);
    Test.assert(v.ready() && v.controller==null);
    v.back();
    Test.assert(v.stage == -1);
    v.shutdown();
    return true;
}

class MissionMemory {
    var value=null;
    var fail=false;
    function initialize() {}
    function read(key) { return RaceForgeJourneyData.copy(value); }
    function write(key,v) { if(fail) { throw new Lang.Exception("offline storage"); } value=RaceForgeJourneyData.copy(v); }
}
(:test)
function missionCompletionIsConfirmedAndRestores(logger as Logger) as Boolean {
    var port=new MissionMemory(); var w=new PaceWeekly(port); w.open(:LIVE); w.journey.data["configured"]=true;
    for(var i=0;i<4;i+=1) { w.select(); }
    Test.assert(w.journey.data["configured"]);
    var m=w.begin(0); Test.assert(m!=null && w.journey.completed()==0);
    var result={:goalMet=>true,:sessionSec=>m["durationTargetSec"],:movingSec=>0,:unknownMotionSec=>m["durationTargetSec"],:effort=>1};
    Test.assert(w.finish(result,:LIVE));
    Test.assert(w.journey.completed()==1);
    Test.assert(w.finish(result,:LIVE) && w.journey.completed()==1);
    var restored=new PaceWeekly(port); restored.open(:LIVE);
    Test.assert(restored.journey.completed()==1 && restored.journey.nextIndex()==1);
    Test.assert(restored.journey.data["history"][0]["unknownMotionSec"]==m["durationTargetSec"]);
    return true;
}
(:test)
function missionPartialAndDemoNeverAwardLiveProgress(logger as Logger) as Boolean {
    var port=new MissionMemory(); var w=new PaceWeekly(port); w.open(:LIVE); w.journey.data["configured"]=true;
    w.begin(0);
    var result={:goalMet=>false,:sessionSec=>20,:movingSec=>0,:unknownMotionSec=>20};
    Test.assert(w.finish(result,:LIVE) && w.journey.completed()==0);
    var liveSequence=port.value["sequence"];
    w.open(:DEMO); w.journey.data["configured"]=true; w.begin(0); result[:goalMet]=true;
    Test.assert(w.finish(result,:DEMO) && w.journey.completed()==1);
    Test.assert(port.value["sequence"]==liveSequence);
    var restored=new PaceWeekly(port); restored.open(:LIVE);
    Test.assert(restored.journey.completed()==0);
    return true;
}
(:test)
function missionSaveFailureRollsBackAndRetries(logger as Logger) as Boolean {
    var port=new MissionMemory(); var w=new PaceWeekly(port); w.open(:LIVE); w.journey.data["configured"]=true;
    w.begin(0); port.fail=true;
    var result={:goalMet=>true,:sessionSec=>300,:movingSec=>0,:unknownMotionSec=>300};
    Test.assert(!w.finish(result,:LIVE));
    Test.assert(w.journey.completed()==0 && w.pending!=null);
    port.fail=false;
    Test.assert(w.finish(result,:LIVE) && w.journey.completed()==1);
    port.value={"schemaVersion"=>999};
    var bad=new PaceWeekly(port); bad.open(:LIVE);
    Test.assert(bad.begin(0)==null && port.value["schemaVersion"]==999);
    return true;
}
(:test)
function missionsKeepPacePilotRecoveryAndFueling(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.autoLink=false; v.config=Config.defaults(); v.mode=:DEMO;
    v.weekly=new PaceWeekly(new MissionMemory()); v.weekly.open(:DEMO); v.weekly.journey.data["configured"]=true;
    v.weekly.screen=:PREVIEW; v.stage=9;
    v.select(); Test.assert(v.stage==8 && v.quick && v.weekly.pending!=null);
    v.share=true; v.select(); Test.assert(v.controller.lifecycle==:ACTIVE && v.controller.config[:goalSec]==180);
    v.task(:food); v.task(:drink);
    Test.assert(v.carbsG==25 && v.fluidMl==150);
    v.controller.dispatch(:END); v.controller.tick(1000);
    Test.assert(v.controller.lifecycle==:COMPLETE && v.weekly.journey.completed()==0);
    v.select(); v.select(); v.select();
    Test.assert(v.feedbackStage==3 && v.weekly.pending==null && v.weekly.journey.completed()==0);
    Test.assert(v.controller.summary[:effort]==v.effort && v.controller.summary[:carbsG]==25);
    v.shutdown(); return true;
}
(:test)
function missionAdjustmentsAndSummitAreExplicit(logger as Logger) as Boolean {
    var w=new PaceWeekly(new MissionMemory()); w.open(:LIVE); w.journey.data["configured"]=true;
    w.screen=:HOME; w.menu(); w.select(); // changes
    w.option=3; w.select(); // propose skip
    Test.assert(w.journey.missions()[0]["status"].equals("planned"));
    w.confirm=true; w.select();
    Test.assert(w.journey.nextIndex()==1 && w.journey.completed()==0);
    for(var i=1;i<w.journey.missions().size()-1;i+=1) {
        w.begin(i); Test.assert(w.finish({:goalMet=>true,:sessionSec=>300,:movingSec=>300,:unknownMotionSec=>0},:LIVE));
    }
    Test.assert(!w.journey.isComplete());
    w.begin(w.journey.nextIndex());
    Test.assert(w.journey.isComplete());
    return true;
}

(:test)
function weeklyNavigationDropsAbandonedDashboardPlan(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.mode=:DEMO;
    v.weekly=new PaceWeekly(new MissionMemory());
    v.planGoalSec=900; v.planId="stay_active:real:2026-11-14"; v.planDemo=false;
    v.task(:missions);
    Test.assert(v.planId==null && v.planGoalSec==null && !v.planDemo);
    v.back(); Test.assert(v.stage==-1);
    v.shutdown(); return true;
}
(:test)
function completedMissionUsesExistingFeedback(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.config=Config.defaults(); v.mode=:DEMO;
    v.weekly=new PaceWeekly(new MissionMemory()); v.weekly.open(:DEMO); v.weekly.journey.data["configured"]=true;
    v.weekly.screen=:PREVIEW; v.stage=9; v.select(); v.select();
    for(var i=0;i<45;i+=1) { v.onTick(); }
    Test.assert(v.controller.lifecycle==:COMPLETE && v.weekly.journey.completed()==0);
    v.task(:food); // complete workout does not change fuel totals
    v.select(); v.select(); v.select();
    Test.assert(v.feedbackStage==3 && v.weekly.journey.completed()==1);
    v.select(); Test.assert(v.ready());
    v.shutdown(); return true;
}
(:test)
function weeklyScreensRenderOnNativeContext(logger as Logger) as Boolean {
    var w=new PaceWeekly(new MissionMemory()); w.open(:DEMO); w.journey.data["configured"]=true;
    var ref=Toybox.Graphics.createBufferedBitmap({:width=>260,:height=>260});
    var surface=ref.get(); var dc=surface.getDc();
    for(var step=0;step<4;step+=1) { w.draw(dc); w.select(); }
    w.draw(dc); w.select(); w.draw(dc); w.select(); w.draw(dc);
    w.menu(); w.draw(dc); w.select(); w.draw(dc); w.select(); w.draw(dc);
    return true;
}

(:test)
function missionCancellationKeepsNormalStart(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.config=Config.defaults(); v.mode=:DEMO;
    v.weekly=new PaceWeekly(new MissionMemory()); v.weekly.open(:DEMO); v.weekly.journey.data["configured"]=true;
    v.weekly.screen=:PREVIEW; v.stage=9; v.select();
    Test.assert(v.weekly.pending!=null);
    v.back(); Test.assert(v.stage==9 && v.weekly.pending==null && v.planGoalSec==null);
    v.weekly.screen=:HOME; v.back(); v.select(); v.select();
    Test.assert(v.controller.lifecycle==:ACTIVE && !v.missionSession);
    v.shutdown(); return true;
}
(:test)
function walkAndMobilityMissionsNeverOfferRunning(logger as Logger) as Boolean {
    var v=new PacePilotView();
    v.missionSession=true;
    v.missionKind="walk"; Test.assert(!v.missionAllowsRunning());
    v.missionKind="recovery"; Test.assert(!v.missionAllowsRunning());
    v.missionKind="mobility"; Test.assert(!v.missionAllowsRunning());
    v.missionKind="easy"; Test.assert(v.missionAllowsRunning());
    v.missionSession=false; Test.assert(v.missionAllowsRunning());
    v.shutdown(); return true;
}

(:test)
function unfinishedSetupCannotStartOrAdjustMission(logger as Logger) as Boolean {
    var w=new PaceWeekly(new MissionMemory()); w.open(:LIVE);
    w.menu(); Test.assert(w.screen==:SETUP);
    Test.assert(w.begin(0)==null && w.pending==null && !w.back());
    Test.assert(w.journey.data["revision"]==0);
    return true;
}
