import Toybox.Application;
import Toybox.Lang;

module RaceForgeJourneyData {
    function copy(value) {
        if(value instanceof Array) {
            var a=[]; for(var i=0;i<value.size();i+=1) { a.add(copy(value[i])); } return a;
        }
        if(value instanceof Dictionary) {
            var d={}; var keys=value.keys();
            for(var j=0;j<keys.size();j+=1) { d[keys[j]]=copy(value[keys[j]]); } return d;
        }
        return value;
    }
    function integer(v,low,high) {
        return v instanceof Number && v>=low && v<=high;
    }
    function resultValid(r) {
        return r instanceof Dictionary && integer(r.get("sessionId"),1,1000000000) &&
            r.get("mode") instanceof String && r["mode"].equals("LIVE") &&
            r.get("goalMet") instanceof Boolean && Contracts.numberIn(r.get("elapsedSec"),0,3600) &&
            Contracts.numberIn(r.get("movingSec"),0,3600) && Contracts.numberIn(r.get("unknownMotionSec"),0,3600);
    }
    function valid(d) {
        if(!(d instanceof Dictionary) || d.get("schemaVersion")!=1 ||
            !RaceForgeWeeklyPlan.validProfile(d.get("profile")) ||
            !(d.get("missions") instanceof Array) || !(d.get("history") instanceof Array) ||
            !(d.get("adjustments") instanceof Array) || !(d.get("availableDays") instanceof Array) ||
            !integer(d.get("revision"),0,1000000000) || !integer(d.get("sequence"),0,1000000000)) { return false; }
        if(!(d.get("challenge") instanceof String) || !d["challenge"].equals("WEEKLY") ||
            !(d.get("configured") instanceof Boolean)) { return false; }
        var items=d["missions"];
        if(items.size()<4 || items.size()>5 || d["history"].size()>8 || d["adjustments"].size()>12 ||
            !integer(d.get("position"),-1,items.size()-1) || d["availableDays"].size()<3 || d["availableDays"].size()>5) { return false; }
        var highest=-1; var ids=[];
        for(var i=0;i<items.size();i+=1) {
            var m=items[i];
            if(!(m instanceof Dictionary) || !(m.get("missionId") instanceof String) ||
                !(m.get("title") instanceof String) || m["title"].length()>40 ||
                !(m.get("activityType") instanceof String) || !(m.get("status") instanceof String) ||
                !integer(m.get("plannedDay"),1,7) || !(m.get("optional") instanceof Boolean) ||
                !integer(m.get("durationTargetSec"),0,3600) || !integer(m.get("hrLow"),40,210) ||
                !integer(m.get("hrHigh"),50,220) || m["hrHigh"]-m["hrLow"]<10 ||
                !(m.get("effortTarget") instanceof String)) { return false; }
            for(var id=0;id<ids.size();id+=1) { if(ids[id].equals(m["missionId"])) { return false; } }
            ids.add(m["missionId"]);
            if(!m["status"].equals("planned") && !m["status"].equals("missed") &&
                !m["status"].equals("complete") && !m["status"].equals("skipped")) { return false; }
            if(m["activityType"].equals("summit")) {
                if(i!=items.size()-1 || m["durationTargetSec"]!=0 || m["status"].equals("skipped")) { return false; }
            } else if(m["durationTargetSec"]<60 || d["availableDays"].indexOf(m["plannedDay"])==-1) { return false; }
            if(m["status"].equals("complete")) {
                if(!resultValid(m.get("result"))) { return false; } highest=i;
            }
        }
        if(d["position"]!=highest) { return false; }
        for(var j=0;j<d["history"].size();j+=1) { if(!resultValid(d["history"][j])) { return false; } }
        for(var k=0;k<d["availableDays"].size();k+=1) { if(!integer(d["availableDays"][k],1,7)) { return false; } }
        return true;
    }
}
class RaceForgeStoragePort {
    function initialize() {}
    function read(key) { return Application.Storage.getValue(key); }
    function write(key,value) { Application.Storage.setValue(key,value); }
}
// Injectable port for a separate test namespace or in-memory test store.
class RaceForgeJourneyRepository {
    var port;
    var key="raceforge.weekly.v1";
    var writable=true;
    var error="";
    function initialize(storagePort) { port=storagePort; }
    function load() {
        var d=null;
        try { d=port.read(key); } catch(e) { writable=false; error="Storage unavailable"; }
        if(d!=null && RaceForgeJourneyData.valid(d)) { return new RaceForgeWeeklyJourney(RaceForgeJourneyData.copy(d)); }
        if(d!=null) { writable=false; error="Stored week needs review"; }
        // Never overwrite an unrecognized/corrupt saved week with default progress.
        return new RaceForgeWeeklyJourney(RaceForgeWeeklyPlan.generate(RaceForgeWeeklyPlan.defaults()));
    }
    function save(journey) {
        if(!writable || !RaceForgeJourneyData.valid(journey.data)) { error="Cannot save this week"; return false; }
        try { port.write(key,RaceForgeJourneyData.copy(journey.data)); error=""; return true; }
        catch(e) { error="Save failed; try again"; return false; }
    }
}
