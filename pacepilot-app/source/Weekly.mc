import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

// Mission metadata surrounds the existing PacePilot workout; never owns sensors/timers.
class PaceWeekly {
    var repo;
    var live;
    var demo;
    var journey;
    var mode=:LIVE;
    var screen=:HOME;
    var selected=0;
    var option=0;
    var setupStep=0;
    var profile;
    var proposal=null;
    var confirm=false;
    var pending=null;
    var status="";
    var summit=new RaceForgeSummitRenderer();
    function initialize(port) {
        repo=new RaceForgeJourneyRepository(port); repo.key="pacepilot.weekly.v1";
        live=repo.load(); profile=RaceForgeJourneyData.copy(live.data["profile"]);
        demo=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(profile));
        journey=live; status=repo.error;
    }
    function open(source) {
        mode=source; journey=mode==:LIVE ? live : demo;
        screen=journey.data["configured"] ? :HOME : :SETUP;
        setupStep=0; selected=journey.nextIndex();
    }
    function persist(before) {
        if(mode==:DEMO || repo.save(live)) { return true; }
        journey.data=before; status=repo.error; return false;
    }
    function begin(index) {
        if(journey.data["configured"]!=true || pending!=null || index!=journey.nextIndex() || journey.isComplete()) { return null; }
        var m=journey.missions()[index];
        if(m["activityType"].equals("summit")) {
            var before=RaceForgeJourneyData.copy(journey.data);
            var id=journey.data["sequence"]+1;
            journey.finish(index,{"sessionId"=>id,"mode"=>mode==:LIVE ? "LIVE" : "DEMO",
                "goalMet"=>true,"elapsedSec"=>0,"movingSec"=>0,"unknownMotionSec"=>0});
            if(persist(before)) { status="Week reviewed"; screen=:HOME; }
            return null;
        }
        var before=RaceForgeJourneyData.copy(journey.data);
        journey.data["sequence"]+=1;
        if(!persist(before)) { return null; }
        pending={"index"=>index,"id"=>journey.data["sequence"],"mode"=>mode};
        status="";
        return m;
    }
    function cancel() { pending=null; }
    function finish(summary,source) {
        if(pending==null) { return true; }
        if(source!=pending["mode"]) { status="Mission source changed"; return false; }
        var before=RaceForgeJourneyData.copy(journey.data);
        var r={"sessionId"=>pending["id"],"mode"=>source==:LIVE ? "LIVE" : "DEMO",
            "goalMet"=>summary[:goalMet],"elapsedSec"=>summary[:sessionSec],
            "movingSec"=>summary[:movingSec],"unknownMotionSec"=>summary[:unknownMotionSec]};
        var fields=[:effort,:energy,:soreness,:routine,:carbsG,:fluidMl];
        var labels=["effort","energy","soreness","routine","carbsG","fluidMl"];
        for(var i=0;i<fields.size();i+=1) { if(summary.hasKey(fields[i])) { r[labels[i]]=summary[fields[i]]; } }
        if(!journey.finish(pending["index"],r)) { status="Mission result unavailable"; return false; }
        if(!persist(before)) { return false; }
        status=source==:DEMO ? "Demo progress only" : (r["goalMet"] ? "Checkpoint saved" : "Partial session saved");
        pending=null; return true;
    }
    // A returned mission is handed to PacePilot's normal review, never run here.
    function select() {
        if(screen==:SETUP) {
            if(setupStep<3) { setupStep+=1; return null; }
            var fresh=new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(profile));
            fresh.data["configured"]=true;
            if(mode==:LIVE) {
                if(live.data["revision"]>0) { status="Week already started"; screen=:HOME; return null; }
                if(!repo.save(fresh)) { status=repo.error; return null; }
                live=fresh;
            } else { demo=fresh; }
            journey=fresh; screen=:HOME; status="";
        } else if(screen==:HOME) { selected=journey.nextIndex(); screen=:LIST; }
        else if(screen==:LIST) { screen=:PREVIEW; }
        else if(screen==:PREVIEW) { return begin(selected); }
        else if(screen==:OPTIONS) {
            if(option==0) { screen=:CHANGE; option=0; }
            else if(journey.data["revision"]==0) { profile=RaceForgeJourneyData.copy(journey.data["profile"]); setupStep=0; screen=:SETUP; }
            else { status="Week already started"; screen=:HOME; }
        } else if(screen==:CHANGE) {
            proposal=RaceForgePlanChanges.propose(journey,selected,["missed","shorten","move","skip"][option]);
            confirm=false; screen=:CONFIRM;
        } else if(screen==:CONFIRM) {
            if(confirm && proposal["allowed"]) {
                var before=RaceForgeJourneyData.copy(journey.data);
                if(RaceForgePlanChanges.confirm(journey,proposal) && !persist(before)) { return null; }
            }
            screen=:HOME;
        }
        return null;
    }
    function move(delta) {
        if(screen==:SETUP) {
            var k=["level","days","activity","time"][setupStep];
            profile[k]=setupStep==1 ? (profile[k]-3+delta+3)%3+3 : (profile[k]+delta+3)%3;
        } else if(screen==:LIST) { selected=(selected+delta+journey.missions().size())%journey.missions().size(); }
        else if(screen==:OPTIONS) { option=1-option; }
        else if(screen==:CHANGE) { option=(option+delta+4)%4; }
        else if(screen==:CONFIRM) { confirm=!confirm; }
    }
    function menu() { if(journey.data["configured"]!=true) { return; } selected=journey.nextIndex(); screen=:OPTIONS; option=0; }
    function back() {
        if(journey.data["configured"]!=true || screen==:HOME || screen==:SETUP) { return false; }
        if(screen==:PREVIEW) { screen=:LIST; }
        else { screen=:HOME; }
        return true;
    }
    function line(dc,y,text,color) {
        var label=text;
        var radius=dc.getWidth()/2-5;
        var dy=dc.getHeight()/2-y;
        var bottom=y+dc.getFontHeight(Graphics.FONT_XTINY)-dc.getHeight()/2;
        if(bottom>dy) { dy=bottom; }
        var square=radius*radius-dy*dy;
        var maximum=square>0 ? 2*Math.sqrt(square) : 0;
        if(maximum>190) { maximum=190; }
        while(dc.getTextWidthInPixels(label,Graphics.FONT_XTINY)>maximum && label.length()>1) {
            label=label.substring(0,label.length()-1);
        }
        dc.setColor(color,Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2,y,Graphics.FONT_XTINY,label,Graphics.TEXT_JUSTIFY_CENTER);
    }
    function draw(dc) {
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK); dc.clear();
        line(dc,20,mode==:DEMO ? "WEEKLY / DEMO" : "WEEKLY / LIVE",Graphics.COLOR_ORANGE);
        var items=journey.missions(); var m=items[selected];
        if(screen==:HOME) {
            line(dc,48,journey.isComplete() ? "Week reviewed" : "Your weekly adventure",Graphics.COLOR_WHITE);
            summit.draw(dc,journey);
            line(dc,178,journey.completed()+" / "+items.size()+" checkpoints",Graphics.COLOR_WHITE);
            line(dc,202,status.length()>0 ? status : "START missions / MENU options",Graphics.COLOR_LT_GRAY);
        } else if(screen==:SETUP) {
            line(dc,65,["Fitness baseline","Available days","Preferred activity","Daily time"][setupStep],Graphics.COLOR_WHITE);
            var value=setupStep==0 ? ["Beginner","Intermediate","Experienced"][profile["level"]] :
                (setupStep==1 ? profile["days"]+" days" : (setupStep==2 ? ["Walk","Run / walk","Mixed"][profile["activity"]] : ["Short","Medium","Long"][profile["time"]]));
            line(dc,110,value,Graphics.COLOR_ORANGE);
            line(dc,155,"UP / DOWN changes",Graphics.COLOR_WHITE);
            line(dc,188,status.length()>0 ? status : "Relative days 1-7",Graphics.COLOR_LT_GRAY);
            line(dc,214,setupStep==3 ? "START creates week" : "START next",Graphics.COLOR_WHITE);
        } else if(screen==:LIST || screen==:PREVIEW) {
            line(dc,65,m["title"],Graphics.COLOR_WHITE);
            line(dc,103,"Day "+m["plannedDay"]+" / "+(m["durationTargetSec"]/60)+" min",Graphics.COLOR_ORANGE);
            line(dc,138,m["status"],Graphics.COLOR_WHITE);
            line(dc,174,selected==journey.nextIndex() ? "Next mission" : "Review only",Graphics.COLOR_LT_GRAY);
            line(dc,208,screen==:LIST ? "UP/DOWN browse / START preview" : (m["activityType"].equals("summit") ? "START confirms weekly check-in" : "START opens workout review"),Graphics.COLOR_WHITE);
        } else if(screen==:OPTIONS) {
            line(dc,75,"Weekly options",Graphics.COLOR_WHITE);
            line(dc,115,option==0 ? "Adjust next mission" : "Personalize unstarted week",Graphics.COLOR_ORANGE);
            line(dc,170,"UP/DOWN / START choose",Graphics.COLOR_WHITE);
        } else if(screen==:CHANGE) {
            line(dc,75,"Adjust next mission",Graphics.COLOR_WHITE);
            line(dc,115,["Mark missed","Shorten optional","Move to free day","Skip"][option],Graphics.COLOR_ORANGE);
            line(dc,170,"START reviews change",Graphics.COLOR_WHITE);
        } else if(screen==:CONFIRM) {
            line(dc,75,proposal["why"],Graphics.COLOR_WHITE);
            line(dc,120,confirm && proposal["allowed"] ? "Confirm change" : "Keep original",Graphics.COLOR_ORANGE);
            line(dc,175,"UP/DOWN / START confirms",Graphics.COLOR_WHITE);
        }
    }
}
