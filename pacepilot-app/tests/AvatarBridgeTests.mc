import Toybox.Test;
import Toybox.Lang;
import Toybox.Graphics;

(:test)
module AvatarFixture {
    function features() {
        var f = Fixture.features(130, true, :MOVING);
        f[:sourceStatus] = {:hr=>:VALID, :speed=>:VALID};
        f[:speedMps] = 2.5;
        return f;
    }
    function decision(advice) {
        return {:advice=>advice, :reason=>:COMFORTABLE, :decisionId=>42, :canResumeRun=>false};
    }
}

(:test)
function avatarBridgeLifecycleAndAdvice(logger as Logger) as Boolean {
    var b = new AvatarBridge(); var f = AvatarFixture.features();
    var d = AvatarFixture.decision(:RUN_EASY); var config = Config.defaults();
    var states = [:SETUP,:READY,:ACTIVE,:PAUSED,:COMPLETE];
    var expected = [:STARTING,:STARTING,:RUNNING_HAPPY,:PAUSED,:CELEBRATING];
    for (var i=0;i<states.size();i++) {
        var m=b.model(f,d,states[i],config,1000);
        Test.assert(m.visualState==expected[i]);
        Test.assert(m.lifecycle==(i==0 ? :READY : states[i]));
    }
    var advice=[:RUN_EASY,:EASE_OFF,:WALK,:READY_TO_RUN];
    expected=[:RUNNING_HAPPY,:RUNNING_WINDED,:WALKING,:RECOVERING];
    for (var k=0;k<advice.size();k++) {
        d[:advice]=advice[k];
        var next=b.model(f,d,:ACTIVE,config,1000);
        Test.assert(next.visualState==expected[k] && next.advice==advice[k]);
        Test.assert(next.decisionId==42 && next.reason==:COMFORTABLE);
        var ctx=b.context(b.snapshot(f),b.decision(d),config);
        Test.assert(ctx.sustained==(advice[k]==:EASE_OFF || advice[k]==:WALK));
        Test.assert(!ctx.allowBuildEffort && ctx.workoutType==:EASY_RUN);
    }
    d[:canResumeRun]=true;
    Test.assert(b.model(f,d,:ACTIVE,config,0).visualState==:READY_TO_RUN);
    var missing=b.model(f,{},:ACTIVE,config,0);
    Test.assert(missing.advice==:UNKNOWN && missing.reason==:UNKNOWN && missing.decisionId==null && !missing.canResumeRun);
    Test.assert(d[:decisionId]==42 && f[:sourceStatus][:hr]==:VALID);
    return true;
}

(:test)
function avatarBridgeEffortAndAuthority(logger as Logger) as Boolean {
    var b=new AvatarBridge(); var f=AvatarFixture.features();
    var d=AvatarFixture.decision(:RUN_EASY); var c=Config.defaults();
    var readings=[114,115,119,120,140,141,145,146,200];
    var bands=[:BELOW,:BELOW,:BELOW,:TARGET,:TARGET,:ABOVE,:ABOVE,:VERY_HIGH,:VERY_HIGH];
    for(var i=0;i<readings.size();i++) {
        f[:hrBpm]=readings[i];
        var m=b.model(f,d,:ACTIVE,c,1000);
        Test.assert(m.effortBand==bands[i]);
        Test.assert(m.visualState!=:RUNNING_WINDED && m.visualState!=:RUNNING_EXHAUSTED);
        Test.assert(m.flush==0 && !m.showSweat && !m.headline.equals("BUILD EFFORT"));
    }
    d[:advice]=:EASE_OFF;
    Test.assert(b.model(f,d,:ACTIVE,c,1000).visualState==:RUNNING_EXHAUSTED);
    c[:hrLowBpm]=160; c[:hrHighBpm]=180; f[:hrBpm]=170;
    Test.assert(b.model(f,d,:ACTIVE,c,1000).effortBand==:TARGET);
    f[:hrReady]=false;
    Test.assert(b.model(f,d,:ACTIVE,c,1000).effortBand==:UNKNOWN);
    return true;
}

(:test)
function avatarBridgeSourceModeAndStill(logger as Logger) as Boolean {
    var b=new AvatarBridge(); var f=AvatarFixture.features();
    var d=AvatarFixture.decision(:RUN_EASY); var c=Config.defaults();
    var statuses=[:STALE,:MISSING,:UNSUPPORTED,:ERROR,:UNKNOWN,null,"VALID"];
    for(var i=0;i<statuses.size();i++) {
        f[:sourceStatus][:hr]=statuses[i];
        var m=b.model(f,d,:ACTIVE,c,1000);
        Test.assert(m.hrText.equals("HR --") && m.visualState==:SENSOR_UNAVAILABLE && m.effortBand==:UNKNOWN);
    }
    f[:sourceStatus]={};
    Test.assert(b.model(f,d,:ACTIVE,c,0).visualState==:SENSOR_UNAVAILABLE);
    f=AvatarFixture.features(); f[:hrReady]=false;
    Test.assert(b.model(f,d,:ACTIVE,c,0).hrText.equals("HR --"));
    f[:hrReady]=true; f[:hrBpm]=null;
    Test.assert(b.model(f,d,:ACTIVE,c,0).visualState==:SENSOR_UNAVAILABLE);
    f=AvatarFixture.features();
    Test.assert(b.model(f,d,:ACTIVE,c,0).modeText.equals("DEMO 4x"));
    f[:mode]=:LIVE;
    Test.assert(b.model(f,d,:ACTIVE,c,0).modeText.equals("LIVE"));
    Test.assert(b.model(f,d,:ACTIVE,c,0).hrText.equals("HR 130"));
    f[:sourceStatus][:speed]=:STALE;
    Test.assert(b.model(f,d,:ACTIVE,c,0).paceText.equals("PACE --"));
    f[:sourceStatus][:speed]=:VALID; f[:movement]=:STILL;
    var still=b.model(f,d,:ACTIVE,c,900);
    Test.assert(still.motion==:IDLE && still.frame==0 && still.paceText.equals("PACE --"));
    return true;
}

(:test)
function avatarBridgeRenderProbe(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.mode=:DEMO;
    v.controller=Fixture.controller(180,:DEMO,:STANDARD);
    var c=v.controller; c.features=AvatarFixture.features();
    var dc=new DrawingProbe();
    var advice=[:RUN_EASY,:EASE_OFF,:WALK,:READY_TO_RUN];
    for(var i=0;i<advice.size();i++) {
        c.decision=AvatarFixture.decision(advice[i]);
        Presenter.render(dc,v);
        c.features[:hrBpm]=200; Presenter.render(dc,v);
        c.features[:hrReady]=false; Presenter.render(dc,v);
        c.features[:hrReady]=true; c.features[:hrBpm]=130;
    }
    c.decision[:canResumeRun]=true; Presenter.render(dc,v);
    Test.assert(dc.texts.indexOf("Try running?")!=-1 && dc.texts.indexOf("MENU offers run option")!=-1);
    c.features[:movement]=:STILL; c.decision[:advice]=:RUN_EASY; Presenter.render(dc,v);
    Test.assert(dc.texts.indexOf("Stopped? Pause to rest")!=-1);
    c.features[:movement]=:MOVING; c.features[:terrain]=:UP; c.decision[:advice]=:EASE_OFF;
    Presenter.render(dc,v); Test.assert(dc.texts.indexOf("Ease off: Climb likely")!=-1);
    var headlines=["Stopped? Pause to rest","Ease off: Climb likely","HR unavailable","Try running?","RECOVER COMFORTABLY"];
    for(var j=0;j<headlines.size();j++) {
        Test.assert(Presenter.textFitsCircle(dc,headlines[j],Presenter.headlineFont(dc,headlines[j],190),190));
    }
    c.lifecycle=:PAUSED; Presenter.render(dc,v);
    Test.assert(dc.texts.indexOf("Paused")!=-1 && dc.texts.indexOf("BACK end session")!=-1);
    // READY/COMPLETE models still render as bounded components, even though
    // these crowded parent screens deliberately remain text-only.
    var states=[:READY,:COMPLETE];
    for(var k=0;k<states.size();k++) {
        var m=v.avatarBridge.model(c.features,c.decision,states[k],c.config,3000);
        v.avatarRenderer.draw(dc,m,12,24,72,84);
    }
    c.lifecycle=:ACTIVE; v.metricsPage=true; Presenter.render(dc,v);
    Test.assert(dc.texts.indexOf("HR ok  GPS ok")!=-1 && dc.texts.indexOf("ACC --  BAR --")!=-1);
    v.shutdown(); return true;
}

(:test)
function avatarRedrawIsolation(logger as Logger) as Boolean {
    var v=new PacePilotView(); v.mode=:DEMO;
    v.controller=Fixture.controller(180,:DEMO,:STANDARD);
    v.controller.features=AvatarFixture.features();
    v.onShow(); v.onShow();
    Test.assert(v.avatarTimer!=null);
    var t=v.avatarTimer; var events=v.controller.events.size();
    var f=v.controller.features; var decision=v.controller.decision;
    for(var i=0;i<20;i++) { v.onAvatarTick(); }
    Test.assert(v.avatarTimer==t && v.virtualMs==0 && v.controller.sessionSec==0);
    Test.assert(v.controller.features==f && v.controller.decision==decision && v.controller.events.size()==events);
    v.prepareAvatar(1000); v.avatarLastReal=1000; v.prepareAvatar(2250);
    Test.assert(v.avatarElapsed==1250);
    v.metricsPage=true; v.syncAvatarTimer(); Test.assert(v.avatarTimer==null);
    v.metricsPage=false; v.syncAvatarTimer(); Test.assert(v.avatarTimer!=null);
    v.endConfirm=true; v.syncAvatarTimer(); Test.assert(v.avatarTimer==null);
    v.endConfirm=false; v.syncAvatarTimer(); Test.assert(v.avatarTimer!=null);
    v.onHide(); v.onHide(); v.onAvatarTick(); Test.assert(v.avatarTimer==null);
    v.onShow(); Test.assert(v.avatarTimer!=null);
    v.controller.lifecycle=:PAUSED; v.syncAvatarTimer(); Test.assert(v.avatarTimer==null);
    v.controller.lifecycle=:COMPLETE; v.feedbackStage=3; v.syncAvatarTimer(); Test.assert(v.avatarTimer==null);
    v.shutdown(); return true;
}

(:test)
function avatarNativeCircularText(logger as Logger) as Boolean {
    var ref=Graphics.createBufferedBitmap({:width=>260,:height=>260});
    var bitmap=ref.get() as Graphics.BufferedBitmap;
    var dc=bitmap.getDc();
    var headlines=["Stopped? Pause to rest","Ease off: Climb likely","HR unavailable","Try running?",
        "RECOVER COMFORTABLY","NICE & EASY","NICE RHYTHM","FOLLOW COACH","STAY COMFORTABLE","EASE YOUR PACE","WALK BREAK"];
    for(var i=0;i<headlines.size();i++) {
        var font=Presenter.headlineFont(dc,headlines[i],190);
        Test.assert(Presenter.textFitsCircle(dc,headlines[i],font,190));
        Test.assert(190+dc.getFontHeight(font)<=218);
    }
    Test.assert(Presenter.textFitsCircle(dc,"DEMO 4x",Graphics.FONT_XTINY,14));
    Test.assert(Presenter.textFitsCircle(dc,"MENU offers run option",Graphics.FONT_XTINY,59));
    Test.assert(Presenter.textFitsCircle(dc,"60:00 / 60:00",Graphics.FONT_XTINY,218));
    Test.assert(Presenter.textFitsCircle(dc,"BACK end session",Graphics.FONT_XTINY,211));
    return true;
}
