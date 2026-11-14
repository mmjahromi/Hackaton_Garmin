import Toybox.Lang;

// All persisted dictionaries use string keys and JSON-like value types.
module RaceForgeWeeklyPlan {
    function defaults() { return {"level"=>0,"days"=>3,"activity"=>2,"time"=>0}; }
    function validProfile(p) {
        return p instanceof Dictionary && Contracts.numberIn(p.get("level"),0,2) &&
            Contracts.numberIn(p.get("days"),3,5) && Contracts.numberIn(p.get("activity"),0,2) &&
            Contracts.numberIn(p.get("time"),0,2);
    }
    function generate(profile) {
        var p = validProfile(profile) ? profile : defaults();
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
        return {"schemaVersion"=>1,"challenge"=>"WEEKLY","profile"=>p,"availableDays"=>days,
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
    function completed() {
        var count=0; var items=missions();
        for(var i=0;i<items.size();i+=1) { if(items[i]["status"].equals("complete")) { count+=1; } }
        return count;
    }
    function finish(index, result) {
        var items=missions(); var m=items[index];
        if (m["status"].equals("complete") || m["status"].equals("skipped")) { return false; }
        var history=data["history"];
        for(var i=0;i<history.size();i+=1) {
            if(history[i]["sessionId"]==result["sessionId"]) { return false; }
        }
        history.add(result);
        if(history.size()>8) { data["history"]=history.slice(history.size()-8,history.size()); }
        if(result["goalMet"]) {
            m["status"]="complete"; m["result"]=result;
            if(index>data["position"]) { data["position"]=index; }
        }
        data["revision"]+=1;
        return true;
    }
}
