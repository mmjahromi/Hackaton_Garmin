import Toybox.Test;
import Toybox.Lang;

(:test)
class FakeStore {
    var writes = 0;
    var fail = false;
    var last = null;
    function initialize() {}
    function save(s) { writes++; last = s; return !fail; }
}
(:test)
module Fixture {
    function features(hr, ready, movement) {
        return {:nowMs=>0, :hrBpm=>hr, :hrReady=>ready, :speedMps=>null,
            :movement=>movement, :terrain=>:UNKNOWN, :sourceStatus=>{}, :mode=>:DEMO};
    }
    function frame(now, hr, speed, motion, pressure) {
        var f = Contracts.emptyFrame(now, :DEMO, now/1000);
        var values = [hr,speed,motion,pressure];
        var keys = [:hr,:speed,:motionRms,:pressure];
        for (var i=0; i<4; i++) {
            f[keys[i]] = Contracts.reading(values[i], now, values[i] == null ? :MISSING : :VALID);
        }
        f[:gpsQuality] = speed == null ? :MISSING : :GOOD;
        return f;
    }
    function controller(goal, mode, scenario) {
        var c = Config.defaults(); c[:goalSec] = goal;
        var result = new SessionController(c,new ReplayProvider(scenario),new FakeStore(),mode);
        result.dispatch(:START); result.tick(0);
        return result;
    }
    function advance(c, start, end) {
        for (var t=start; t<=end; t++) { c.tick(t*1000); }
    }
}

(:test)
function T01_thresholds(logger as Logger) as Boolean {
    var e = new CoachEngine(Config.defaults()); var m = e.initialMemory();
    for (var t=1;t<=60;t++) {
        var r = e.step(Fixture.features(141,true,:MOVING),m,1,null); m=r[:memory];
        Test.assert(m[:advice] == (t<15 ? :RUN_EASY : (t<60 ? :EASE_OFF : :WALK)));
    }
    m=e.initialMemory();
    for (var i=0;i<14;i++) { m=e.step(Fixture.features(141,true,:STILL),m,1,null)[:memory]; }
    m=e.step(Fixture.features(140,true,:STILL),m,1,null)[:memory];
    Test.assert(m[:highSec] == 0 && m[:advice] == :RUN_EASY);
    return true;
}

(:test)
function T01_rawReplay(logger as Logger) as Boolean {
    var c=Fixture.controller(180,:DEMO,:STANDARD);
    for(var t=1;t<=180;t++) {
        if(t==160) { c.dispatch(:ACCEPT_RUN); }
        c.tick(t*1000);
    }
    var expected= [36,81,141,160];
    var advice=[:EASE_OFF,:WALK,:READY_TO_RUN,:RUN_EASY];
    Test.assert(c.transitions.size()==4);
    for(var i=0;i<4;i++) {
        logger.debug("Replay t="+c.transitions[i][:at]+" "+c.transitions[i][:advice]);
        Test.assert(c.transitions[i][:at]==expected[i] && c.transitions[i][:advice]==advice[i]);
    }
    Test.assert(c.lifecycle==:COMPLETE && c.sessionSec==180 && c.summary[:goalMet]);
    Test.assert(c.store.writes==0);
    return true;
}

(:test)
function T02_noise(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults());
    var f=null;
    for(var t=0;t<5;t++) { f=p.update(Fixture.frame(t*1000,t==2?170:130,2,150,100000),t*1000); }
    Test.assert(f[:hrBpm]==130);
    var e=new CoachEngine(Config.defaults()); var m=e.initialMemory();
    for(var i=0;i<150;i++) { m=e.step(Fixture.features(i%2==0?139:141,true,:MOVING),m,1,null)[:memory]; }
    Test.assert(m[:advice]==:RUN_EASY);
    return true;
}

(:test)
function T03_recovery(logger as Logger) as Boolean {
    var e=new CoachEngine(Config.defaults()); var m=e.initialMemory();
    m[:advice]=:WALK; m[:walkSec]=58; m[:lowSec]=29;
    m=e.step(Fixture.features(135,true,:MOVING),m,1,null)[:memory];
    Test.assert(m[:advice]==:WALK);
    m=e.step(Fixture.features(135,true,:MOVING),m,1,null)[:memory];
    Test.assert(m[:advice]==:READY_TO_RUN);
    m=e.step(Fixture.features(136,true,:MOVING),m,1,:ACCEPT_RUN)[:memory];
    Test.assert(m[:advice]==:WALK && m[:lowSec]==0);
    for(var i=0;i<30;i++) { m=e.step(Fixture.features(135,true,:UNKNOWN),m,1,null)[:memory]; }
    Test.assert(m[:advice]==:READY_TO_RUN);
    m=e.step(Fixture.features(135,true,:UNKNOWN),m,1,:ACCEPT_RUN)[:memory];
    Test.assert(m[:advice]==:RUN_EASY && m[:highSec]==0 && m[:walkSec]==0);
    return true;
}

(:test)
function T03_stillRevokes(logger as Logger) as Boolean {
    var e=new CoachEngine(Config.defaults()); var m=e.initialMemory();
    m[:advice]=:READY_TO_RUN;
    m=e.step(Fixture.features(130,true,:STILL),m,1,:ACCEPT_RUN)[:memory];
    Test.assert(m[:advice]==:WALK && m[:lowSec]==0);
    return true;
}

(:test)
function T04_hrLossEveryState(logger as Logger) as Boolean {
    var e=new CoachEngine(Config.defaults());
    var states=[:RUN_EASY,:EASE_OFF,:WALK,:READY_TO_RUN];
    for(var i=0;i<states.size();i++) {
        var m=e.initialMemory(); m[:advice]=states[i]; m[:highSec]=59; m[:lowSec]=29; m[:walkSec]=60;
        var r=e.step(Fixture.features(null,false,:MOVING),m,1,:ACCEPT_RUN);
        Test.assert(r[:memory][:advice]==(states[i]==:READY_TO_RUN?:WALK:states[i]));
        Test.assert(r[:memory][:highSec]==0 && r[:memory][:lowSec]==0);
        Test.assert(!r[:decision][:canResumeRun] && r[:decision][:reason]==:HR_UNAVAILABLE);
    }
    return true;
}

(:test)
function T04_freshnessAndReacquisition(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults()); var f=null;
    for(var t=0;t<=10;t++) { f=p.update(Fixture.frame(t*1000,130,2,150,100000),t*1000); }
    Test.assert(f[:hrReady]);
    var cached=Fixture.frame(10000,130,2,150,100000);
    for(var k=11;k<=15;k++) { f=p.update(cached,k*1000); }
    Test.assert(p.hr.status==:VALID);
    f=p.update(cached,16000);
    Test.assert(!f[:hrReady] && f[:hrBpm]==null && f[:sourceStatus][:hr]==:STALE);
    for(var j=17;j<27;j++) {
        f=p.update(Fixture.frame(j*1000,130,2,150,100000),j*1000); Test.assert(!f[:hrReady]);
    }
    f=p.update(Fixture.frame(27000,130,2,150,100000),27000);
    Test.assert(f[:hrReady]);
    f=p.update(Fixture.frame(28000,null,2,150,100000),28000);
    Test.assert(f[:hrBpm]==null && !f[:hrReady]);
    return true;
}

(:test)
function T04_cachedSamplesNotDuplicated(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults());
    var f=Fixture.frame(0,130,2,150,100000);
    for(var t=0;t<5;t++) { p.update(f,t*1000); }
    Test.assert(p.hr.samples.size()==1);
    return true;
}

(:test)
function T05_pauseAndGap(logger as Logger) as Boolean {
    var c=Fixture.controller(180,:DEMO,:STANDARD);
    Fixture.advance(c,1,35); Test.assert(c.memory[:highSec]==14);
    c.dispatch(:PAUSE); c.tick(35000);
    Fixture.advance(c,36,95);
    Test.assert(c.sessionSec==35 && c.lifecycle==:PAUSED && c.memory[:highSec]==0);
    c.dispatch(:RESUME); c.tick(95000);
    c.tick(96000); Test.assert(!c.features[:hrReady]);
    var before=c.sessionSec;
    c.tick(101000); Test.assert(c.sessionSec==before && c.memory[:highSec]==0);
    c.tick(100000); Test.assert(c.sessionSec==before);
    return true;
}

(:test)
function T06_eventsAndMode(logger as Logger) as Boolean {
    var c=Fixture.controller(180,:LIVE,:TOTAL_LOSS);
    c.dispatch(:START); c.tick(1000);
    Test.assert(c.sessionSec==1 && !c.setMode(:DEMO));
    c.dispatch(:WALK_NOW); c.tick(2000); Test.assert(c.memory[:advice]==:WALK);
    c.dispatch(:ACCEPT_RUN); c.dispatch(:END); c.tick(3000);
    Test.assert(c.lifecycle==:COMPLETE && !c.summary[:goalMet] && c.store.writes==1);
    c.dispatch(:END); c.tick(4000); Test.assert(c.store.writes==1);
    return true;
}

(:test)
function T06_manualWalkRestartsMinimum(logger as Logger) as Boolean {
    var e=new CoachEngine(Config.defaults()); var m=e.initialMemory();
    m[:advice]=:READY_TO_RUN; m[:walkSec]=90; m[:lowSec]=40;
    m=e.step(Fixture.features(130,true,:MOVING),m,1,:WALK_NOW)[:memory];
    Test.assert(m[:advice]==:WALK && m[:walkSec]==0 && m[:lowSec]==0);
    return true;
}

(:test)
function T07_goalAndUnknownMovement(logger as Logger) as Boolean {
    var c=Fixture.controller(60,:LIVE,:TOTAL_LOSS);
    Fixture.advance(c,1,60);
    Test.assert(c.lifecycle==:COMPLETE && c.sessionSec==60 && c.summary[:goalMet]);
    Test.assert(c.movingSec==0 && c.unknownMotionSec==60 && c.hrValidSec==0);
    Fixture.advance(c,61,90); Test.assert(c.store.writes==1);
    return true;
}

(:test)
function T08_totalLossControls(logger as Logger) as Boolean {
    var c=Fixture.controller(60,:DEMO,:TOTAL_LOSS);
    Fixture.advance(c,1,15);
    Test.assert(c.features[:hrBpm]==null && c.features[:speedMps]==null);
    Test.assert(c.decision[:reason]==:HR_UNAVAILABLE && !c.decision[:canResumeRun]);
    var statuses=c.features[:sourceStatus].values();
    for(var i=0;i<statuses.size();i++) { Test.assert(statuses[i]==:MISSING); }
    c.dispatch(:PAUSE); c.tick(15000); Test.assert(c.lifecycle==:PAUSED);
    c.dispatch(:END); c.tick(15000); Test.assert(c.lifecycle==:COMPLETE);
    return true;
}

(:test)
function T09_motionFallback(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults()); var f=null;
    for(var t=0;t<=3;t++) { f=p.update(Fixture.frame(t*1000,130,null,150,100000),t*1000); }
    Test.assert(f[:movement]==:MOVING);
    p.reset();
    for(var k=0;k<=10;k++) { f=p.update(Fixture.frame(k*1000,130,0,null,100000),k*1000); }
    Test.assert(f[:movement]==:STILL);
    p.reset();
    for(var j=0;j<=12;j++) { f=p.update(Fixture.frame(j*1000,130,0,150,100000),j*1000); }
    Test.assert(f[:movement]==:MOVING);
    f=p.update(Fixture.frame(13000,130,null,null,100000),13000);
    Test.assert(f[:movement]==:UNKNOWN);
    return true;
}

(:test)
function T09_accelerometerReduction(logger as Logger) as Boolean {
    Test.assert(Contracts.motionRms([0,0,0],[0,0,0],[1000,1000,1000])==0);
    Test.assert(Contracts.motionRms([0,0],[0,0],[900,1100])==100);
    Test.assert(Contracts.motionRms([],[],[])==null);
    Test.assert(Contracts.motionRms([1],[1,2],[3])==null);
    Test.assert(Contracts.motionRms([null],[0],[0])==null);
    return true;
}

(:test)
function T10_pressureTrend(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults()); var f=null;
    for(var t=0;t<=45;t++) {
        f=p.update(Fixture.frame(t*1000,130,2,150,100000-t*2),t*1000);
        if(t<43) { Test.assert(f[:terrain]!=:UP); }
    }
    Test.assert(f[:terrain]==:UP);
    f=p.update(Fixture.frame(46000,130,2,150,null),46000);
    Test.assert(f[:terrain]==:UNKNOWN);
    p.reset();
    for(var k=0;k<=45;k++) { f=p.update(Fixture.frame(k*1000,130,2,150,100000+k%2),k*1000); }
    Test.assert(f[:terrain]==:FLAT);
    return true;
}

(:test)
function T10_terrainNeverChangesEffortTiming(logger as Logger) as Boolean {
    var e=new CoachEngine(Config.defaults()); var a=e.initialMemory(); var b=e.initialMemory();
    for(var t=0;t<65;t++) {
        var flat=Fixture.features(150,true,:MOVING); var up=Fixture.features(150,true,:MOVING);
        up[:terrain]=:UP;
        a=e.step(flat,a,1,null)[:memory]; b=e.step(up,b,1,null)[:memory];
        Test.assert(a[:advice]==b[:advice]);
    }
    return true;
}

(:test)
function T11_storageAndAlertGate(logger as Logger) as Boolean {
    var storage=new SummaryStore();
    Test.assert(!storage.validSummary(null) && !storage.validSummary({:schemaVersion=>2}));
    var c=Fixture.controller(60,:LIVE,:TOTAL_LOSS); c.store.fail=true;
    Fixture.advance(c,1,60);
    Test.assert(!c.saved && c.summary!=null && c.store.writes==1);
    var encoded=storage.encode(c.summary); var decoded=storage.decode(encoded);
    Test.assert(storage.validSummary(decoded) && decoded[:sessionSec]==60);
    var config=storage.decode(storage.encode(Config.defaults()));
    Test.assert(Config.valid(config));
    var gate=new AlertGate();
    Test.assert(gate.allow(1,0));
    Test.assert(!gate.allow(1,11000));
    Test.assert(!gate.allow(2,1000));
    Test.assert(!gate.allow(2,12000));
    Test.assert(gate.allow(3,12000));
    return true;
}

(:test)
function T11_demoDoesNotWrite(logger as Logger) as Boolean {
    var c=Fixture.controller(60,:DEMO,:STANDARD);
    Fixture.advance(c,1,60); Test.assert(c.store.writes==0 && c.saved);
    return true;
}

(:test)
function configBounds(logger as Logger) as Boolean {
    var c=Config.defaults(); Test.assert(Config.valid(c));
    c[:hrLowBpm]=135; Test.assert(!Config.valid(c));
    c=Config.defaults(); c[:goalSec]=59; Test.assert(!Config.valid(c));
    c=Config.defaults(); c[:goalSec]=3601; Test.assert(!Config.valid(c));
    Test.assert(!Config.valid({}) && !Config.valid(null));
    return true;
}

(:test)
function T05_resumeRejectsCachedReading(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults());
    p.resetAfter(20000);
    for(var t=20;t<=24;t++) {
        var f=p.update(Fixture.frame(20000,130,2,150,100000),t*1000);
        Test.assert(!f[:hrReady] && f[:hrBpm]==null);
    }
    for(var k=25;k<=34;k++) {
        var next=p.update(Fixture.frame(k*1000,130,2,150,100000),k*1000);
        Test.assert(!next[:hrReady]);
    }
    Test.assert(p.update(Fixture.frame(35000,130,2,150,100000),35000)[:hrReady]);
    return true;
}

(:test)
function T06_restartAndDuplicateEvents(logger as Logger) as Boolean {
    var c=Fixture.controller(60,:DEMO,:STANDARD);
    c.dispatch(:WALK_NOW); c.dispatch(:WALK_NOW); c.tick(1000);
    Test.assert(c.walkPromptCount==1 && c.transitions.size()==1);
    c.dispatch(:END); c.tick(2000);
    c.dispatch(:RESET); c.tick(2000); Test.assert(c.lifecycle==:READY);
    c.dispatch(:START); c.tick(0); // rollback must be ignored
    Test.assert(c.lifecycle==:READY);
    c.tick(2000);
    Test.assert(c.lifecycle==:ACTIVE && c.sessionSec==0 && c.transitions.size()==0);
    return true;
}

(:test)
function T10_deadbandAndLoss(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults()); var f=null;
    for(var t=0;t<=55;t++) {
        f=p.update(Fixture.frame(t*1000,130,2,150,100000-t),t*1000);
    }
    Test.assert(f[:terrain]==:UNKNOWN);
    for(var k=56;k<=70;k++) { f=p.update(Fixture.frame(k*1000,130,0,0,99900),k*1000); }
    Test.assert(f[:movement]==:STILL && f[:terrain]==:UNKNOWN);
    return true;
}

(:test)
function T04_boundsAndFutureReadings(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults());
    var f=p.update(Fixture.frame(0,0,-1,-5,0),0);
    Test.assert(f[:hrBpm]==null && f[:speedMps]==null && f[:terrain]==:UNKNOWN);
    f=p.update(Fixture.frame(2000,130,2,150,100000),1000);
    Test.assert(f[:hrBpm]==null && f[:sourceStatus][:hr]==:MISSING);
    return true;
}

(:test)
class DrawingProbe {
    var texts=[];
    function initialize() {}
    function getTextWidthInPixels(text,font) { return text.length()*8; }
    function setColor(a,b) {}
    function clear() { texts=[]; }
    function setPenWidth(w) {}
    function drawArc(x,y,r,d,a,b) {}
    function drawText(x,y,font,text,justify) {
        Test.assert(text instanceof String);
        Test.assert(y>=0 && y<=260);
        texts.add(text);
    }
}

(:test)
function T08_screenAndControls(logger as Logger) as Boolean {
    var v=new PacePilotView();
    v.config=Config.defaults(); v.mode=:DEMO;
    var dc=new DrawingProbe();
    for(var stage=0;stage<=8;stage++) { v.stage=stage; Presenter.render(dc,v); }
    v.select();
    Test.assert(v.controller.lifecycle==:ACTIVE && v.controller.mode==:DEMO);
    v.controller.dispatch(:PAUSE); v.controller.tick(0); Presenter.render(dc,v);
    Test.assert(v.controller.lifecycle==:PAUSED);
    v.select(); Test.assert(v.controller.lifecycle==:ACTIVE);
    v.back(); Test.assert(v.endConfirm && !v.endYes);
    Presenter.render(dc,v); v.select();
    Test.assert(v.controller.lifecycle==:ACTIVE && !v.endConfirm);
    v.back(); v.adjust(1); v.select();
    Test.assert(v.controller.lifecycle==:COMPLETE);
    Presenter.render(dc,v); v.adjust(1); Presenter.render(dc,v);
    v.select(); Presenter.render(dc,v);
    Test.assert(v.feedbackStage == 1);
    v.select(); Presenter.render(dc,v);
    Test.assert(v.feedbackStage == 2);
    v.select(); Presenter.render(dc,v);
    Test.assert(v.controller.summary[:effort] == 2 && v.controller.summary[:nextGoalSec] == 60);
    v.select(); Test.assert(v.ready());
    v.shutdown();
    return true;
}

(:test)
function T08_renderReplayStates(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.mode=:DEMO;
    v.controller=Fixture.controller(180,:DEMO,:STANDARD);
    var dc=new DrawingProbe();
    for(var t=1;t<=180;t++) {
        if(t==160) { v.controller.dispatch(:ACCEPT_RUN); }
        v.controller.tick(t*1000);
        Presenter.render(dc,v);
        v.metricsPage=true; Presenter.render(dc,v); v.metricsPage=false;
    }
    v.shutdown();
    return true;
}

(:test)
function T11_storageRoundTrip(logger as Logger) as Boolean {
    var s=new SummaryStore();
    var raw=s.encode(Config.defaults());
    Test.assert(raw["schemaVersion"]==1 && raw["hrLowBpm"]==120);
    Test.assert(!s.validSummary(s.decode({"schemaVersion"=>1,"mode"=>7})));
    var c=Fixture.controller(60,:DEMO,:LOSS);
    Fixture.advance(c,1,60);
    Test.assert(s.save(c.summary)); // demo short-circuits storage
    return true;
}

(:test)
function T04_lossReplay(logger as Logger) as Boolean {
    var c=Fixture.controller(180,:DEMO,:LOSS);
    for(var t=1;t<=159;t++) {
        c.tick(t*1000);
        if(t>=115 && t<140) { Test.assert(!c.features[:hrReady] && !c.decision[:canResumeRun]); }
    }
    Test.assert(c.memory[:advice]==:WALK);
    return true;
}

(:test)
function T04_sourceErrorStatus(logger as Logger) as Boolean {
    var p=new FeaturePipeline(Config.defaults());
    var raw=Contracts.emptyFrame(0,:LIVE,0);
    raw[:speed]=Contracts.missing(:ERROR);
    raw[:motionRms]=Contracts.missing(:UNSUPPORTED);
    var f=p.update(raw,0);
    Test.assert(f[:sourceStatus][:speed]==:ERROR && f[:sourceStatus][:motionRms]==:UNSUPPORTED);
    return true;
}

(:test)
function recoveryChoicesAreExplicit(logger as Logger) as Boolean {
    Test.assert(Recovery.suggestedChoice(0,0,1)==1);
    Test.assert(Recovery.suggestedChoice(2,2,0)==1);
    Test.assert(Recovery.suggestedChoice(2,0,2)==1);
    Test.assert(Recovery.suggestedChoice(2,0,1)==0);
    Test.assert(Recovery.nextGoal(1200,0)==1200);
    Test.assert(Recovery.nextGoal(1200,1)==900);
    Test.assert(Recovery.nextGoal(180,1)==60);
    Test.assert(Recovery.nextGoal(301,1)==60);
    Test.assert(Recovery.nextGoal(1200,2)==null);
    return true;
}
(:test)
function sharingDefaultsToLocal(logger as Logger) as Boolean {
    var v=new PacePilotView();
    Test.assert(!v.share && v.sync.status.equals("Kept on watch"));
    var summary={:mode=>:DEMO};
    v.sync.send(summary,true);
    Test.assert(v.sync.status.equals("Kept on watch"));
    return true;
}

(:test)
function hrBandFeedbackBoundaries(logger as Logger) as Boolean {
    Test.assert(HrFeedback.state(null,false,120,140)==:UNKNOWN);
    Test.assert(HrFeedback.state(130,false,120,140)==:UNKNOWN);
    Test.assert(HrFeedback.state(120,true,120,140)==:IN_BAND);
    Test.assert(HrFeedback.state(140,true,120,140)==:IN_BAND);
    Test.assert(HrFeedback.state(145,true,120,140)==:NEAR);
    Test.assert(HrFeedback.state(115,true,120,140)==:NEAR);
    Test.assert(HrFeedback.state(146,true,120,140)==:HIGH);
    Test.assert(HrFeedback.state(114,true,120,140)==:LOW);
    Test.assert(HrFeedback.color(:HIGH,0)!=HrFeedback.color(:HIGH,1000));
    Test.assert(HrFeedback.color(:IN_BAND,0)==HrFeedback.color(:IN_BAND,1000));
    return true;
}
(:test)
function lowBandCueDwell(logger as Logger) as Boolean {
    var g=new LowBandGate();
    Test.assert(!g.update(:LOW,0));
    Test.assert(!g.update(:LOW,14999));
    Test.assert(g.update(:LOW,15000));
    Test.assert(!g.update(:LOW,30000));
    Test.assert(!g.update(:UNKNOWN,31000));
    Test.assert(!g.update(:LOW,32000));
    Test.assert(g.update(:LOW,47000));
    return true;
}

(:test)
function liveFeedRespectsConsentAndRate(logger as Logger) as Boolean {
    Test.assert(!LiveFeedPolicy.due(false,"LIVE",false,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"DEMO",false,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"LIVE",true,10000,null,true));
    Test.assert(!LiveFeedPolicy.due(true,"LIVE",false,4999,0,false));
    Test.assert(LiveFeedPolicy.due(true,"LIVE",false,5000,0,false));
    Test.assert(LiveFeedPolicy.due(true,"LIVE",false,1,0,true));
    return true;
}

(:test)
function liveFeedKeepsLatestPendingState(logger as Logger) as Boolean {
    var feed=new LiveFeed();feed.busy=true;feed.lastStatus="active";
    feed.send({"mode"=>"LIVE","status"=>"paused"},true);
    Test.assert(feed.pending["status"].equals("paused"));
    feed.send({"mode"=>"LIVE","status"=>"active"},true);
    Test.assert(feed.pending["status"].equals("active"));
    feed.send({"mode"=>"LIVE","status"=>"completed"},true);
    Test.assert(feed.pending["status"].equals("completed"));
    return true;
}
