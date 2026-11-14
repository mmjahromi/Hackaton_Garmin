import Toybox.Lang;

class RaceForgeAdventureController {
    var screen=:HOME;
    var mode=:DEMO;
    var selected=0;
    var endYes=false;
    var journey;
    var session=null;
    var status="";
    function initialize() {
        journey=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()));
    }
    function step(delta) {
        if(session!=null && screen==:WORKOUT) {
            session.step(delta);
            if(session.controller.lifecycle==:COMPLETE) { screen=:SUMMARY; }
        }
    }
    function select() {
        status="";
        if(screen==:HOME) { selected=journey.nextIndex(); screen=:LIST; }
        else if(screen==:LIST) { screen=:PREVIEW; }
        else if(screen==:PREVIEW) {
            var m=journey.missions()[selected];
            if(selected!=journey.nextIndex() || m["status"].equals("complete")) { status="Next mission first"; return; }
            journey.data["sequence"]+=1;
            if(m["activityType"].equals("summit")) {
                journey.finish(selected,{"sessionId"=>journey.data["sequence"],"mode"=>"DEMO","goalMet"=>true,
                    "elapsedSec"=>0,"movingSec"=>0,"unknownMotionSec"=>0});
                screen=:HOME;
            } else {
                session=new RaceForgeSessionBridge(m,mode,journey.data["sequence"]);
                screen=:WORKOUT;
            }
        } else if(screen==:WORKOUT) { session.event(:PAUSE); screen=:PAUSE; }
        else if(screen==:PAUSE) { session.event(:RESUME); screen=:WORKOUT; }
        else if(screen==:END_CONFIRM) {
            if(endYes) { session.event(:END); screen=:SUMMARY; }
            else { screen=:PAUSE; }
        } else if(screen==:SUMMARY) {
            journey.finish(selected,session.result()); session.stop(); session=null; screen=:HOME;
        }
    }
    function move(delta) {
        if(screen==:LIST) { selected=(selected+delta+journey.missions().size())%journey.missions().size(); }
        else if(screen==:END_CONFIRM) { endYes=!endYes; }
        else if(screen==:WORKOUT && delta>0) { session.controller.dispatch(:WALK_NOW); }
        else if(screen==:WORKOUT && session.controller.decision[:canResumeRun]) { session.controller.dispatch(:ACCEPT_RUN); }
    }
    function back() {
        if(screen==:WORKOUT || screen==:PAUSE) {
            if(session.controller.lifecycle==:ACTIVE) { session.event(:PAUSE); }
            endYes=false; screen=:END_CONFIRM;
        } else if(screen==:END_CONFIRM) { screen=:PAUSE; }
        else if(screen==:PREVIEW) { screen=:LIST; }
        else if(screen==:LIST) { screen=:HOME; }
    }
    function suspend() {
        if(session!=null && session.controller.lifecycle==:ACTIVE) { session.event(:PAUSE); screen=:PAUSE; }
    }
    function stop() { if(session!=null) { session.stop(); } }
}
