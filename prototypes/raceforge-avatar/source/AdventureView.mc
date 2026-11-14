import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class RaceForgeAdventureView extends WatchUi.View {
    var flow;
    var _summit=new RaceForgeSummitRenderer();
    var _athlete=new RaceForgeAvatarRenderer();
    var _timer=new Timer.Timer();
    var _visible=false;
    var _running=false;
    var _lastNow=0;
    var _surface=null;
    function initialize() { View.initialize(); flow=new RaceForgeAdventureController(); }
    function onShow() as Void { _visible=true; _lastNow=System.getTimer(); syncTimer(); }
    function onHide() as Void { _visible=false; flow.suspend(); syncTimer(); _surface=null; }
    function shutdown() { _visible=false; flow.stop(); syncTimer(); _surface=null; }
    function syncTimer() {
        var active=_visible && flow.screen==:WORKOUT;
        if(active && !_running) { _lastNow=System.getTimer(); _timer.start(method(:onTick),250,true); _running=true; }
        else if(!active && _running) { _timer.stop(); _running=false; }
    }
    function onTick() as Void {
        if(!_visible || !_running) { return; }
        var now=System.getTimer(); flow.step(now-_lastNow); _lastNow=now;
        syncTimer(); WatchUi.requestUpdate();
    }
    function pressSelect() { flow.select(); changed(); }
    function pressMove(delta) { flow.move(delta); changed(); }
    function pressBack() { flow.back(); changed(); }
    function changed() { syncTimer(); if(_visible) { WatchUi.requestUpdate(); } }
    function menu() {
        // Preserve the complete milestone-2 lab and all its regression controls.
        if(flow.screen==:HOME) {
            var lab=new RaceForgeView(); WatchUi.pushView(lab,new RaceForgeDelegate(lab),WatchUi.SLIDE_UP);
        }
    }
    function text(dc,y,message,color) {
        dc.setColor(color,Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2,y,Graphics.FONT_XTINY,message,Graphics.TEXT_JUSTIFY_CENTER);
    }
    function button(dc,label) {
        dc.setColor(0x00AAAA,Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(60,214,140,22,7);
        text(dc,214,label,Graphics.COLOR_BLACK);
    }
    function timeText(seconds) {
        var s=seconds.toNumber(); return (s/60).toString()+":"+(s%60).format("%02d");
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        if(_surface==null) {
            var ref=Graphics.createBufferedBitmap({:width=>dc.getWidth(),:height=>dc.getHeight()});
            _surface=ref.get();
        }
        var surface=_surface as Graphics.BufferedBitmap;
        drawScreen(surface.getDc()); dc.drawBitmap(0,0,surface);
    }
    function drawScreen(dc) {
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK); dc.clear();
        var screen=flow.screen; var journey=flow.journey;
        var items=journey.missions(); var mission=items[flow.selected];
        text(dc,15,"DEMO",0xFFAA00);
        if(screen==:HOME) {
            text(dc,38,"Stay active · 7 days",Graphics.COLOR_WHITE);
            _summit.draw(dc,journey);
            text(dc,184,journey.completed().toString()+" / "+items.size().toString()+" checkpoints",0x00AAAA);
            text(dc,202,items[journey.nextIndex()]["title"],Graphics.COLOR_WHITE);
            button(dc,"START · missions");
        } else if(screen==:LIST) {
            text(dc,48,"Your weekly trail",Graphics.COLOR_WHITE);
            for(var row=0;row<3;row+=1) {
                var index=(flow.selected+row)%items.size(); var m=items[index]; var y=85+row*36;
                if(row==0) { dc.setColor(0x005555,Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(35,y-2,190,30,6); }
                text(dc,y,(index+1).toString()+". "+m["title"],m["status"].equals("complete") ? 0x00AAAA : Graphics.COLOR_WHITE);
            }
            text(dc,193,"UP / DOWN · choose",Graphics.COLOR_LT_GRAY); button(dc,"START · preview");
        } else if(screen==:PREVIEW) {
            text(dc,56,mission["title"],Graphics.COLOR_WHITE);
            text(dc,88,"Day "+mission["plannedDay"].toString()+" · "+timeText(mission["durationTargetSec"]),0x00AAAA);
            text(dc,116,mission["effortTarget"],Graphics.COLOR_WHITE);
            text(dc,143,"Manual band 120-140",Graphics.COLOR_LT_GRAY);
            text(dc,171,"Demo: 180s at 4x",0xFFAA00);
            text(dc,192,flow.status,Graphics.COLOR_WHITE); button(dc,"START · begin");
        } else if(screen==:WORKOUT || screen==:PAUSE) {
            var bridge=flow.session; bridge.refresh(); var model=bridge.avatar;
            text(dc,38,mission["title"],Graphics.COLOR_WHITE);
            _athlete.draw(dc,model,70,57,120,120);
            text(dc,178,model.dataText,0x00AAAA);
            text(dc,198,model.headline,Graphics.COLOR_WHITE);
            text(dc,219,timeText(bridge.controller.sessionSec)+" / "+timeText(bridge.controller.config[:goalSec]),Graphics.COLOR_WHITE);
            text(dc,232,screen==:PAUSE ? "RESUME" : "PAUSE",Graphics.COLOR_LT_GRAY);
        } else if(screen==:END_CONFIRM) {
            text(dc,75,"End this mission?",Graphics.COLOR_WHITE);
            text(dc,108,"Earlier progress stays",0x00AAAA);
            text(dc,140,flow.endYes ? "YES · end" : "NO · keep paused",0xFFAA00);
            text(dc,175,"UP / DOWN · change",Graphics.COLOR_LT_GRAY); button(dc,"START · confirm");
        } else if(screen==:SUMMARY) {
            var s=flow.session.controller.summary;
            text(dc,56,s[:goalMet] ? "Mission complete" : "Session ended",Graphics.COLOR_WHITE);
            text(dc,85,"DEMO · not real exercise",0xFFAA00);
            text(dc,117,"Elapsed "+timeText(s[:sessionSec]),Graphics.COLOR_WHITE);
            text(dc,143,"Moving estimate "+timeText(s[:movingSec]),0x00AAAA);
            text(dc,169,"Unknown "+timeText(s[:unknownMotionSec]),Graphics.COLOR_LT_GRAY);
            button(dc,s[:goalMet] ? "START · checkpoint" : "START · return");
        }
    }
}

class RaceForgeAdventureDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) { BehaviorDelegate.initialize(); view=v; }
    function onSelect() as Boolean { view.pressSelect(); return true; }
    function onNextPage() as Boolean { view.pressMove(1); return true; }
    function onPreviousPage() as Boolean { view.pressMove(-1); return true; }
    function onBack() as Boolean {
        if(view.flow.screen==:HOME) { return false; }
        view.pressBack(); return true;
    }
    function onMenu() as Boolean { view.menu(); return true; }
}
