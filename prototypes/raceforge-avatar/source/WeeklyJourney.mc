import Toybox.Lang;

// All persisted dictionaries use string keys and JSON-like value types.
module RaceForgeWeeklyPlan {
    function defaults() { return {"level"=>0,"days"=>3,"activity"=>2,"time"=>0}; }
    function validProfile(p) {
        return p instanceof Dictionary && p.get("level") instanceof Number && p.get("days") instanceof Number &&
            p.get("activity") instanceof Number && p.get("time") instanceof Number && Contracts.numberIn(p.get("level"),0,2) &&
            Contracts.numberIn(p.get("days"),3,5) && Contracts.numberIn(p.get("activity"),0,2) &&
            Contracts.numberIn(p.get("time"),0,2);
    }
    function generate(profile) {
        var p = validProfile(profile) ? {"level"=>profile["level"],"days"=>profile["days"],"activity"=>profile["activity"],"time"=>profile["time"]} : defaults();
        var days = p["days"] == 3 ? [1,3,5] : (p["days"] == 4 ? [1,3,5,7] : [1,2,3,5,7]);
        var count = p["days"] == 3 ? 3 : 4;
        var minutes = p["level"] == 0 ? [5,10,15][p["time"]] : [10,15,20][p["time"]];
        var types = [p["activity"] == 0 ? "walk" : "easy", "mobility", "recovery", "aerobic"];
        var names = [p["activity"] == 0 ? "Easy walk" : "Easy walk / run", "Mobility", "Recovery walk", "Comfortable aerobic"];
        var missions = [];
        for (var i=0; i<count; i+=1) {
            var duration = minutes*60;
            if (i==1 || i==2) { duration = duration*2/3; }
            missions.add({"missionId"=>"week-"+(i+1).toString(),"title"=>names[i],"activityType"=>types[i],
                "durationTargetSec"=>duration,"effortTarget"=>"comfortable","hrLow"=>120,"hrHigh"=>140,
                "plannedDay"=>days[i],"status"=>"planned","optional"=>i==1 || i==2,"result"=>null});
        }
        missions.add({"missionId"=>"week-summit","title"=>"Celebrate your week","activityType"=>"summit",
            "durationTargetSec"=>0,"effortTarget"=>"check-in","hrLow"=>120,"hrHigh"=>140,
            "plannedDay"=>7,"status"=>"planned","optional"=>false,"result"=>null});
        return {"sourceChoice"=>"DEMO","configured"=>false,"schemaVersion"=>1,"challenge"=>"WEEKLY","profile"=>p,"availableDays"=>days,
            "missions"=>missions,"position"=>-1,"revision"=>0,"sequence"=>0,"history"=>[],"adjustments"=>[]};
    }
}

class RaceForgeWeeklyJourney {
    var data;
    function initialize(state) { data=state; }
    function missions() { return data["missions"]; }
    function nextIndex() {
        var items=missions();
        for (var i=0;i<items.size();i+=1) {
            if (!items[i]["status"].equals("complete") && !items[i]["status"].equals("skipped")) { return i; }
        }
        return items.size()-1;
    }
    function isComplete() { return missions()[missions().size()-1]["status"].equals("complete"); }
    function completed() {
        var count=0; var items=missions();
        for(var i=0;i<items.size();i+=1) { if(items[i]["status"].equals("complete")) { count+=1; } }
        return count;
    }
    function finish(index, result) {
        var items=missions();
        if(!(index instanceof Number) || index<0 || index>=items.size() || index!=nextIndex() ||
            !(result instanceof Dictionary) || !(result.get("sessionId") instanceof Number) ||
            !(result.get("goalMet") instanceof Boolean)) { return false; }
        if(result["sessionId"]<data["sequence"]) { return false; }
        var m=items[index];
        if (m["status"].equals("complete") || m["status"].equals("skipped")) { return false; }
        var history=data["history"];
        for(var i=0;i<history.size();i+=1) {
            if(history[i]["sessionId"]==result["sessionId"]) { return false; }
        }
        result["missionId"]=m["missionId"];
        history.add(result);
        if(result["sessionId"]>data["sequence"]) { data["sequence"]=result["sessionId"]; }
        if(history.size()>8) { data["history"]=history.slice(history.size()-8,history.size()); }
        if(result["goalMet"]) {
            m["status"]="complete"; m["result"]=result;
            if(index>data["position"]) { data["position"]=index; }
        }
        data["revision"]+=1;
        return true;
    }
}

// Adjustment proposals are inert until explicitly confirmed against a revision.
module RaceForgePlanChanges {
    function propose(journey,index,kind) {
        var d=journey.data; var m=journey.missions()[index];
        var p={"revision"=>d["revision"],"index"=>index,"kind"=>kind,"allowed"=>false,
            "missionId"=>m["missionId"],"duration"=>m["durationTargetSec"],"day"=>m["plannedDay"],"why"=>"Keep the original plan"};
        if(m["status"].equals("complete") || m["status"].equals("skipped") || m["activityType"].equals("summit")) {
            p["why"]="Checkpoint is unchanged"; return p;
        }
        if(kind.equals("missed")) { p["allowed"]=true; p["why"]="Mark missed; keep progress"; }
        else if(kind.equals("shorten") && m["optional"]) {
            p["duration"]=m["durationTargetSec"]/2;
            if(p["duration"]<60) { p["duration"]=60; }
            p["allowed"]=p["duration"]<m["durationTargetSec"]; p["why"]="Shorten optional mission";
        } else if(kind.equals("move")) {
            var days=d["availableDays"];
            for(var i=0;i<days.size();i+=1) {
                var busy=false;
                for(var j=0;j<journey.missions().size()-1;j+=1) {
                    var other=journey.missions()[j];
                    if(other["plannedDay"]==days[i] && !other["status"].equals("skipped")) { busy=true; }
                }
                if(!busy && days[i]>m["plannedDay"]) {
                    p["day"]=days[i]; p["allowed"]=true; p["why"]="Move to free day "+days[i].toString(); break;
                }
            }
            if(!p["allowed"]) { p["why"]="No free available day"; }
        } else if(kind.equals("skip")) { p["allowed"]=true; p["why"]="Skip; keep achievements"; }
        else { p["why"]="Only optional missions shorten"; }
        return p;
    }
    function confirm(journey,proposal) {
        if(!(proposal instanceof Dictionary) || !proposal["allowed"] || proposal["revision"]!=journey.data["revision"]) { return false; }
        var current=propose(journey,proposal["index"],proposal["kind"]);
        if(!current["allowed"] || current["day"]!=proposal["day"] || current["duration"]!=proposal["duration"]) { return false; }
        var m=journey.missions()[proposal["index"]]; var kind=proposal["kind"];
        if(kind.equals("skip")) { m["status"]="skipped"; }
        else if(kind.equals("missed")) { m["status"]="missed"; }
        else { m["durationTargetSec"]=proposal["duration"]; m["plannedDay"]=proposal["day"]; m["status"]="planned"; }
        if(kind.equals("move")) {
            // Preserve earned checkpoints; reorder only the remaining itinerary.
            var fixed=[]; var pending=[]; var items=journey.missions();
            for(var a=0;a<items.size()-1;a+=1) {
                if(items[a]["status"].equals("complete") || items[a]["status"].equals("skipped")) { fixed.add(items[a]); }
                else {
                    pending.add(items[a]); var at=pending.size()-1;
                    while(at>0 && pending[at]["plannedDay"]<pending[at-1]["plannedDay"]) {
                        var swap=pending[at-1]; pending[at-1]=pending[at]; pending[at]=swap; at-=1;
                    }
                }
            }
            for(var b=0;b<pending.size();b+=1) { fixed.add(pending[b]); }
            fixed.add(items[items.size()-1]); journey.data["missions"]=fixed;
        }
        var history=journey.data["adjustments"]; history.add(RaceForgeJourneyData.copy(proposal));
        if(history.size()>12) { journey.data["adjustments"]=history.slice(history.size()-12,history.size()); }
        journey.data["revision"]+=1;
        return true;
    }
}
