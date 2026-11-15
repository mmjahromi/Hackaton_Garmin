import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// SessionController owns elapsed time, decisions and the pending result.
// This sink does not persist; the user commits from the adventure summary.
class RaceForgePendingSummary {
    function initialize() {}
    function save(summary) { return true; }
}

// Preserve the shared provider's timestamp domain across resource restarts.
// No sensor calls are reimplemented; acquisition remains in LiveProvider.
class RaceForgeLiveProvider extends LiveProvider {
    var sessionOrigin=null;
    function initialize() { LiveProvider.initialize(); }
    function start() {
        LiveProvider.start();
        if(sessionOrigin==null) { sessionOrigin=origin; } else { origin=sessionOrigin; }
    }
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
    var alerts=new AlertService();
    var hapticsEnabled=false;
    var effort=1; var fatigue=0; var fueling=2; var checkInComplete=false;
    var _lastState=:READY;
    var _lastDecision=-1;
    var _stateStartSec=0.0;
    function initialize(mission, selectedMode, sessionId) {
        mode=selectedMode;
        var c=Config.defaults();
        c[:goalSec]=mode==:DEMO ? 180 : mission["durationTargetSec"];
        c[:hrLowBpm]=mission["hrLow"]; c[:hrHighBpm]=mission["hrHigh"];
        c[:recoverBpm]=c[:hrHighBpm]-5;
        var provider=mode==:LIVE ? new RaceForgeLiveProvider() : new ReplayProvider(:STANDARD);
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
        if(_lastState!=controller.lifecycle || id!=_lastDecision) { _stateStartSec=controller.sessionSec; }
        if(avatar==null || bucket!=_lastBucket || _lastState!=controller.lifecycle || id!=_lastDecision) {
            var features=controller.features;
            if(controller.lifecycle==:PAUSED || controller.lifecycle==:COMPLETE) {
                features={:mode=>mode,:hrBpm=>null,:hrReady=>false,:speedMps=>null,
                    :movement=>:STILL,:sourceStatus=>{:hr=>:MISSING,:speed=>:MISSING}};
            }
            avatar=adapter.fromContext(features,controller.decision,controller.lifecycle,context,0);
            if(context.workoutType==:WALK && avatar.motion==:RUN) { avatar.motion=:WALK; }
            if(context.workoutType==:REST && (avatar.motion==:RUN || avatar.motion==:WALK || avatar.motion==:START)) { avatar.motion=:IDLE; }
            _lastBucket=bucket; _lastState=controller.lifecycle; _lastDecision=id;
        }
        animator.apply(avatar,((controller.sessionSec-_stateStartSec)*(mode==:DEMO ? 250 : 1000)).toNumber());
    }
    function step(realDeltaMs) {
        controller.endedAt=Time.now().value();
        if(controller.lifecycle!=:ACTIVE || realDeltaMs<=0 || realDeltaMs>2000) { return; }
        if(mode==:LIVE) {
            clockMs=controller.provider.now(); controller.tick(clockMs); refresh(); cue(); return;
        }
        // DEMO playback clock only. The shared controller credits all session time.
        var target=clockMs+realDeltaMs*4;
        for(var i=0;i<8 && clockMs<target && controller.lifecycle==:ACTIVE;i+=1) {
            var dt=target-clockMs; if(dt>1000) { dt=1000; }
            clockMs+=dt; controller.tick(clockMs);
        }
        refresh();
    }
    function cue() {
        if(hapticsEnabled && mode==:LIVE && controller.lifecycle==:ACTIVE && controller.features[:hrReady]) {
            var advice=controller.decision[:advice];
            if(advice==:EASE_OFF || advice==:WALK || advice==:READY_TO_RUN) {
                alerts.emit(controller.decision[:decisionId],advice,clockMs);
            }
        }
    }
    function event(value) {
        controller.endedAt=Time.now().value();
        if(mode==:LIVE) {
            if(value==:RESUME && !controller.provider.running) { controller.provider.start(); }
            clockMs=controller.provider.now();
            if(controller.lifecycle==:ACTIVE) { controller.tick(clockMs); }
        }
        controller.dispatch(value); controller.tick(clockMs); refresh();
        if(value==:PAUSE && mode==:LIVE) { controller.provider.stop(); }
    }
    function stop() { controller.stop(); }
    function result() {
        var s=controller.summary;
        return {"schemaVersion"=>1,"sessionId"=>controller.sessionId,"mode"=>mode==:DEMO ? "DEMO" : "LIVE",
            "goalMet"=>s[:goalMet],"elapsedSec"=>s[:sessionSec],"movingSec"=>s[:movingSec],
            "unknownMotionSec"=>s[:unknownMotionSec],"hrValidSec"=>s[:hrValidSec],
            "endedAt"=>s[:endedAt],"effort"=>checkInComplete ? effort : null,"fatigue"=>checkInComplete ? fatigue : null,"fueling"=>checkInComplete ? fueling : null};
    }
}
