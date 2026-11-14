import Toybox.Lang;
import Toybox.System;

// SessionController owns elapsed time and decisions. This sink holds a pending
// result only; the user explicitly commits it from the adventure summary.
class RaceForgePendingSummary {
    function initialize() {}
    function save(summary) { return true; }
}

class RaceForgeSessionBridge {
    var controller;
    var mode;
    var clockMs=0;
    var avatar;
    var adapter=new RaceForgeAvatarAdapter();
    var animator=new RaceForgeAvatarAnimator();
    var context;
    var _lastBucket=-1;
    var _lastState=:READY;
    var _lastDecision=-1;
    function initialize(mission, selectedMode, sessionId) {
        mode=selectedMode;
        var c=Config.defaults();
        c[:goalSec]=mode==:DEMO ? 180 : mission["durationTargetSec"];
        c[:hrLowBpm]=mission["hrLow"]; c[:hrHighBpm]=mission["hrHigh"];
        c[:recoverBpm]=c[:hrHighBpm]-5;
        var provider=new ReplayProvider(:STANDARD);
        controller=new SessionController(c,provider,new RaceForgePendingSummary(),mode);
        controller.sessionId=sessionId;
        var type=mission["activityType"];
        context=new RaceForgeAvatarWorkoutContext(type.equals("mobility") ? :REST :
            (type.equals("walk") || type.equals("recovery") ? :WALK : :EASY_RUN),c[:hrLowBpm].toFloat(),c[:hrHighBpm].toFloat());
        controller.dispatch(:START); controller.tick(0);
        refresh();
    }
    function refresh() {
        var id=controller.decision[:decisionId];
        var bucket=clockMs/1000;
        if(avatar==null || bucket!=_lastBucket || _lastState!=controller.lifecycle || id!=_lastDecision) {
            avatar=adapter.fromContext(controller.features,controller.decision,controller.lifecycle,context,0);
            _lastBucket=bucket; _lastState=controller.lifecycle; _lastDecision=id;
        }
        animator.apply(avatar,(controller.sessionSec*1000).toNumber());
    }
    function step(realDeltaMs) {
        if(controller.lifecycle!=:ACTIVE || realDeltaMs<=0 || realDeltaMs>2000) { return; }
        // DEMO playback clock only. The shared controller credits all session time.
        var target=clockMs+realDeltaMs*4;
        for(var i=0;i<8 && clockMs<target && controller.lifecycle==:ACTIVE;i+=1) {
            var dt=target-clockMs; if(dt>1000) { dt=1000; }
            clockMs+=dt; controller.tick(clockMs);
        }
        refresh();
    }
    function event(value) {
        controller.dispatch(value); controller.tick(clockMs); refresh();
    }
    function stop() { controller.stop(); }
    function result() {
        var s=controller.summary;
        return {"schemaVersion"=>1,"sessionId"=>controller.sessionId,"mode"=>mode==:DEMO ? "DEMO" : "LIVE",
            "goalMet"=>s[:goalMet],"elapsedSec"=>s[:sessionSec],"movingSec"=>s[:movingSec],
            "unknownMotionSec"=>s[:unknownMotionSec],"hrValidSec"=>s[:hrValidSec],
            "effort"=>1,"fatigue"=>0,"fueling"=>2};
    }
}
