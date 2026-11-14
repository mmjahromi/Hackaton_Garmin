import Toybox.Lang;

class RaceForgeAdventureController {
    var screen=:SETUP;
    var mode=:DEMO;
    var selected=0;
    var endYes=false;
    var journey;
    var liveJourney;
    var demoJourney;
    var repository=null;
    var session=null;
    var status="";
    var setupStep=0;
    var setupProfile=RaceForgeWeeklyPlan.defaults();
    var option=0;
    var bandChoice=1;
    var checkStep=0;
    var checkChoice=1;
    var proposal=null;
    function initialize() {
        liveJourney=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(setupProfile));
        demoJourney=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(setupProfile));
        journey=demoJourney;
    }
    function restore(repo) {
        repository=repo; liveJourney=repo.load(); setupProfile=RaceForgeJourneyData.copy(liveJourney.data["profile"]);
        demoJourney=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(setupProfile));
        var source=liveJourney.data.get("sourceChoice");
        mode=source instanceof String && source.equals("LIVE") ? :LIVE : :DEMO;
        journey=mode==:LIVE ? liveJourney : demoJourney;
        if(liveJourney.data.get("configured")==true || liveJourney.data["revision"]>0) { screen=:HOME; }
        status=repo.error;
    }
    function setMode(value) {
        var previous=liveJourney.data.get("sourceChoice");
        liveJourney.data["sourceChoice"]=value==:LIVE ? "LIVE" : "DEMO";
        if(repository!=null && !repository.save(liveJourney)) { liveJourney.data["sourceChoice"]=previous; }
        mode=value; journey=mode==:LIVE ? liveJourney : demoJourney;
        selected=journey.nextIndex(); screen=:HOME; status="";
    }
    function persist() { return mode==:DEMO || repository==null || repository.save(liveJourney); }
    function step(delta) {
        if(session!=null && screen==:WORKOUT) {
            session.step(delta);
            if(session.controller.lifecycle==:COMPLETE) { screen=:SUMMARY; }
        }
    }
    function finishSetup() {
        if(liveJourney.data["revision"]>0) { screen=:HOME; status="Week already started"; return; }
        var fresh=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(setupProfile));
        fresh.data["configured"]=true; fresh.data["sourceChoice"]=mode==:LIVE ? "LIVE" : "DEMO";
        if(repository!=null && !repository.save(fresh)) { status=repository.error; return; }
        liveJourney=fresh;
        demoJourney=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(setupProfile));
        journey=mode==:LIVE ? liveJourney : demoJourney;
        screen=:HOME; status="";
    }
    function marker() {
        var before=RaceForgeJourneyData.copy(journey.data);
        journey.data["sequence"]+=1;
        journey.finish(selected,{"sessionId"=>journey.data["sequence"],"mode"=>mode==:DEMO ? "DEMO" : "LIVE",
            "goalMet"=>true,"elapsedSec"=>0,"movingSec"=>0,"unknownMotionSec"=>0});
        if(!persist()) { journey.data=before; status="Save failed; retry"; return; }
        screen=:HOME; status=journey.completed()==journey.missions().size() ? "Week complete" : "Week reviewed";
    }
    function commitResult() {
        if(session==null) { return false; }
        var before=RaceForgeJourneyData.copy(journey.data);
        var result=session.result();
        if(!journey.finish(selected,result)) { return false; }
        if(!persist()) { journey.data=before; status="Save failed; retry"; return false; }
        session.stop(); session=null; screen=:HOME;
        status=mode==:DEMO ? "Demo progress only" : "Result saved";
        if(result.get("fatigue")==2) {
            proposal=RaceForgePlanChanges.propose(journey,journey.nextIndex(),"shorten");
            selected=journey.nextIndex();
            if(proposal["allowed"]) { screen=:ADJUST_CONFIRM; endYes=false; }
            else { screen=:ADJUST; option=0; }
        }
        return true;
    }
    function select() {
        status="";
        if(screen==:SETUP) {
            if(setupStep<3) { setupStep+=1; } else { finishSetup(); }
        } else if(screen==:HOME) { selected=journey.nextIndex(); screen=:LIST; }
        else if(screen==:LIST) { screen=:PREVIEW; }
        else if(screen==:PREVIEW) {
            var m=journey.missions()[selected];
            if(selected!=journey.nextIndex() || m["status"].equals("complete")) { status="Next mission first"; return; }
            if(m["activityType"].equals("summit")) { marker(); return; }
            var before=RaceForgeJourneyData.copy(journey.data);
            journey.data["sequence"]+=1;
            if(!persist()) { journey.data=before; status="Cannot save session"; return; }
            session=new RaceForgeSessionBridge(m,mode,journey.data["sequence"]);
            session.hapticsEnabled=mode==:LIVE;
            screen=:WORKOUT;
        } else if(screen==:WORKOUT) { session.event(:PAUSE); screen=:PAUSE; }
        else if(screen==:PAUSE) { session.event(:RESUME); screen=:WORKOUT; }
        else if(screen==:END_CONFIRM) {
            if(endYes) { session.event(:END); screen=:SUMMARY; }
            else { screen=:PAUSE; }
        } else if(screen==:SUMMARY) { screen=:CHECKIN; checkStep=0; checkChoice=1; }
        else if(screen==:CHECKIN) {
            if(checkStep==0) { session.effort=checkChoice; checkChoice=0; }
            else if(checkStep==1) { session.fatigue=checkChoice; checkChoice=2; }
            else { session.fueling=checkChoice; session.checkInComplete=true; commitResult(); return; }
            checkStep+=1;
        } else if(screen==:OPTIONS) {
            if(option==0) { screen=:SOURCE; option=mode==:DEMO ? 0 : 1; }
            else if(option==1) {
                if(liveJourney.data["revision"]>0) { status="Week already started"; screen=:HOME; }
                else { screen=:SETUP; setupStep=0; }
            }
        } else if(screen==:SOURCE) { setMode(option==0 ? :DEMO : :LIVE); }
        else if(screen==:BAND) {
            var before=RaceForgeJourneyData.copy(journey.data); var m=journey.missions()[selected];
            m["hrLow"]=110+bandChoice*10; m["hrHigh"]=130+bandChoice*10;
            if(!persist()) { journey.data=before; status="Band not saved"; }
            screen=:PREVIEW;
        } else if(screen==:ADJUST) {
            if(option==0) { screen=:PREVIEW; }
            else {
                proposal=RaceForgePlanChanges.propose(journey,selected,["keep","missed","shorten","move","skip"][option]);
                endYes=false; screen=:ADJUST_CONFIRM;
            }
        } else if(screen==:ADJUST_CONFIRM) {
            if(endYes && proposal["allowed"]) {
                var before=RaceForgeJourneyData.copy(journey.data);
                if(RaceForgePlanChanges.confirm(journey,proposal) && !persist()) {
                    journey.data=before; status="Change not saved"; return;
                }
            }
            screen=:HOME;
        }
    }
    function move(delta) {
        if(screen==:SETUP) {
            var key=["level","days","activity","time"][setupStep];
            var value=setupProfile[key]+delta;
            if(setupStep==1) { value=(value-3+3)%3+3; } else { value=(value+3)%3; }
            setupProfile[key]=value;
        } else if(screen==:LIST) { selected=(selected+delta+journey.missions().size())%journey.missions().size(); }
        else if(screen==:END_CONFIRM || screen==:ADJUST_CONFIRM) { endYes=!endYes; }
        else if(screen==:OPTIONS) { option=(option+delta+3)%3; }
        else if(screen==:SOURCE) { option=1-option; }
        else if(screen==:BAND) { bandChoice=(bandChoice+delta+3)%3; }
        else if(screen==:ADJUST) { option=(option+delta+5)%5; }
        else if(screen==:CHECKIN) { checkChoice=(checkChoice+delta+3)%3; }
        else if(screen==:PREVIEW && selected==journey.nextIndex() && !journey.missions()[selected]["activityType"].equals("summit")) {
            bandChoice=1; screen=:BAND;
        } else if(screen==:WORKOUT && delta>0) { session.controller.dispatch(:WALK_NOW); }
        else if(screen==:WORKOUT && session.controller.decision[:canResumeRun]) { session.controller.dispatch(:ACCEPT_RUN); }
    }
    function menu() {
        if(screen==:HOME) { option=0; screen=:OPTIONS; }
        else if(screen==:PREVIEW) { option=0; screen=:ADJUST; }
        else if(screen==:SUMMARY) { commitResult(); }
    }
    function back() {
        if(screen==:WORKOUT || screen==:PAUSE) {
            if(session.controller.lifecycle==:ACTIVE) { session.event(:PAUSE); }
            endYes=false; screen=:END_CONFIRM;
        } else if(screen==:END_CONFIRM) { screen=:PAUSE; }
        else if(screen==:CHECKIN) { screen=:SUMMARY; }
        else if(screen==:PREVIEW || screen==:BAND || screen==:ADJUST) { screen=:LIST; }
        else if(screen!=:HOME && screen!=:SUMMARY) { screen=:HOME; }
    }
    function suspend() {
        if(session!=null && session.controller.lifecycle==:ACTIVE) { session.event(:PAUSE); screen=:PAUSE; }
    }
    function stop() { if(session!=null) { session.stop(); } }
}
