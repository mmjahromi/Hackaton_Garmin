import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;
import Toybox.Graphics;

class PacePilotApp extends Application.AppBase {
    var view;
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        view = new PacePilotView();
        // The app opens on its "press START to open" screen. Tests build the
        // view directly and skip it.
        view.activated = false;
        return [view, new Delegate(view)];
    }
    function onStop(state) as Void { if (view != null) { view.shutdown(); } }
}

class PacePilotView extends WatchUi.View {
    // Presentation owns a separate redraw clock; the session timer below is unchanged.
    var avatarBridge = new AvatarBridge();
    var avatarRenderer = new RaceForgeAvatarRenderer();
    var avatarAnimator = new RaceForgeAvatarAnimator();
    var avatarModel = null;
    var avatarElapsed = 0;
    var avatarLastReal = null;
    var avatarTimer = null;
    var avatarVisible = false;
    var avatarSurface = null;
    var avatarSurfaceTried = false;
    var config;
    var storage;
    var controller = null;
    var alerts;
    var timer = null;
    var mode = :LIVE;
    var scenario = :STANDARD;
    // -1 is the home screen. START there goes straight to the review screen
    // (stage 8); the step-by-step settings (0-7) are reached from the menu.
    var stage = -1;
    var quick = false;
    // "Get today's plan": the dashboard's suggestion, shown for the user to
    // accept. Nothing here changes a setting until START is pressed.
    var planScreen = null;
    var planGoalSec = null;
    var planId = null;
    var planSync = new PlanSync();
    // First screen after tapping the app: nothing happens until START.
    var activated = true;
    var autoLink = true;       // reach the dashboard on activation (off in tests)
    var splashIcon = null;
    // Fuelling inside a workout: a drink cue and one-press logging from the
    // menu, so a long session does not need a second app.
    var drinkMode = 0;         // 0 auto, 1 off, 2/3/4 = every 10/15/20 min
    var fluidMl = 0;
    var carbsG = 0;
    var lastDrinkSec = 0;
    var drinkDue = false;
    var drinkCueId = -1000;
    var effort_meter = new EffortMeter();
    var planDemo = false;      // the accepted plan came from the demo data
    var linkTried = false;     // connect to the dashboard once per launch
    var demoTried = false;
    var origin = 0;
    var virtualMs = 0;
    var lastReal = null;
    var endConfirm = false;
    var endYes = false;
    var summaryPage = 0;
    var metricsPage = false;
    var configSaved = true;
    var energy = 1;
    var soreness = 0;
    var share = false;
    var todayChoice = 0;
    var feedbackStage = 0;
    var effort = 1;
    var nextChoice = 0;
    var routine = 0;
    var sync;
    var liveFeed=new LiveFeed();
    var lowCueId = -2;
    var lowGate = new LowBandGate();
    var historyIndex = -1;
    var lastSummary;
    var weekly=null;
    var missionSession=false;
    var missionTitle="";
    var missionKind="";
    function initialize() {
        View.initialize();
        storage = new SummaryStore();
        sync = new DashboardSync();
        config = storage.loadConfig();
        lastSummary = storage.load();
        alerts = new AlertService();
    }
    function onShow() as Void {
        avatarVisible = true;
        avatarLastReal = System.getTimer();
        syncAvatarTimer();
        if (timer == null) {
            timer = new Timer.Timer();
            timer.start(method(:onTick), 1000, true);
        }
    }
    // START on the opening screen. Activating the app starts by reaching the
    // dashboard. That never blocks: BACK or START dismisses it, and the app
    // works the same offline.
    function activate() {
        activated = true;
        if (!linkTried && autoLink) { linkTried = true; requestPlan(); }
        syncAvatarTimer(); WatchUi.requestUpdate();
    }
    function splash() {
        if (splashIcon == null) {
            try { splashIcon = WatchUi.loadResource(Rez.Drawables.SplashIcon); } catch (e) { splashIcon = null; }
        }
        return splashIcon;
    }
    function onHide() as Void {
        avatarVisible = false;
        syncAvatarTimer();
        avatarLastReal = null;
        avatarSurface = null;
        avatarSurfaceTried = false;
    }
    function shutdown() {
        onHide();
        if (timer != null) { timer.stop(); timer = null; }
        if (controller != null) { controller.stop(); }
    }
    function ready() { return controller == null || controller.lifecycle == :READY; }
    function missionAllowsRunning() { return !missionSession || missionKind.equals("easy") || missionKind.equals("aerobic"); }
    function startSession() {
        if (!Config.valid(config)) { return; }
        missionSession=weekly!=null && weekly.pending!=null;
        liveFeed = new LiveFeed();
        sync = new DashboardSync();
        configSaved = storage.saveConfig(config);
        var c = Config.defaults();
        c[:hrLowBpm] = config[:hrLowBpm]; c[:hrHighBpm] = config[:hrHighBpm];
        c[:recoverBpm] = config[:recoverBpm];
        c[:goalSec] = mode == :DEMO ? 180 : (planGoalSec != null ? planGoalSec : Recovery.nextGoal(config[:goalSec], todayChoice));
        var provider = mode == :LIVE ? new LiveProvider() : new ReplayProvider(scenario);
        avatarModel = null; avatarElapsed = 0;
        controller = new SessionController(c, provider, storage, mode);
        controller.sessionId = Time.now().value();
        origin = System.getTimer(); lastReal = origin; virtualMs = 0;
        lowGate = new LowBandGate(); alerts = new AlertService(); summaryPage = 0; feedbackStage = 0; effort = 1; routine = 0;
        fluidMl = 0; carbsG = 0; lastDrinkSec = 0; drinkDue = false;
        effort_meter = new EffortMeter();
        controller.dispatch(:START); controller.tick(0);
    }
    function onTick() as Void {
        if (controller != null && controller.lifecycle != :READY && controller.lifecycle != :COMPLETE) {
            var realNow = System.getTimer();
            controller.endedAt = Time.now().value();
            if (mode == :LIVE) { controller.tick(realNow - origin); }
            else {
                var realGap = realNow - lastReal;
                if (realGap > 2000 || realGap < 0) {
                    controller.pipeline.reset(); controller.resetDwell();
                } else if (controller.lifecycle == :PAUSED) { controller.tick(virtualMs); }
                else {
                    for (var i = 0; i < 4 && controller.lifecycle == :ACTIVE; i++) {
                        virtualMs += 1000;
                        if (virtualMs == 160000 && missionAllowsRunning()) { controller.dispatch(:ACCEPT_RUN); }
                        controller.tick(virtualMs);
                        signal(realNow);
                    }
                }
            }
            lastReal = realNow;
            signal(realNow);
            drinkCue(realNow);
            // One sample per real second in a live session.
            if (mode == :LIVE) { effort_meter.add(controller.lifecycle, controller.features); }
        }
        publishLive();
        syncAvatarTimer(); WatchUi.requestUpdate();
    }
    // Raises the drink cue once when the chosen interval has passed since
    // the last logged drink. It clears when a drink is logged.
    function drinkCue(now) {
        if (controller.lifecycle != :ACTIVE || drinkDue) { return; }
        var every = Fuel.intervalSec(drinkMode, controller.config[:goalSec]);
        if (Fuel.due(controller.sessionSec, lastDrinkSec, every)) {
            drinkDue = true;
            alerts.emit(drinkCueId, :DRINK, now);
            drinkCueId--;
        }
    }
    function publishLive() {
        if (controller == null || controller.lifecycle == :READY) { return; }
        var c=controller;var f=c.features;
        var state=c.lifecycle == :COMPLETE ? "completed" : (c.lifecycle == :PAUSED ? "paused" : "active");
        liveFeed.send({"schemaVersion"=>1,"app"=>"pacepilot","mode"=>mode == :LIVE ? "LIVE" : "DEMO",
          "sessionId"=>c.sessionId,"status"=>state,"elapsedSec"=>c.sessionSec.toNumber(),
          "goalSec"=>c.config[:goalSec],"movingSec"=>c.movingSec.toNumber(),
          "heartRate"=>state.equals("active") && f[:hrReady] ? f[:hrBpm] : null,
          "speedMps"=>state.equals("active") ? f[:speedMps] : null,
          "carbsG"=>carbsG,"fluidMl"=>fluidMl},share);
    }
    function signal(now) {
        var band=controller.lifecycle == :ACTIVE ? HrFeedback.state(controller.features[:hrBpm],controller.features[:hrReady],controller.config[:hrLowBpm],controller.config[:hrHighBpm]) : :UNKNOWN;
        if (lowGate.update(band,now)) { alerts.emit(lowCueId,:LOW,now); lowCueId--; }
        if (controller.lifecycle == :ACTIVE && controller.features[:hrReady]) {
            var a = controller.decision[:advice];
            if (a == :EASE_OFF || a == :WALK || (a == :READY_TO_RUN && missionAllowsRunning())) {
                alerts.emit(controller.decision[:decisionId], a, now);
            }
        }
    }
    function select() {
        if (!activated) { activate(); return; }
        if (ready() && stage==9) {
            var mission=weekly.select();
            if(mission!=null) { missionTitle=mission["title"]; missionKind=mission["activityType"]; planScreen=null; planId=null; planDemo=false; planGoalSec=mission["durationTargetSec"]; stage=8; quick=true; }
            WatchUi.requestUpdate(); return;
        }
        if (historyIndex >= 0) { historyIndex = -1; syncAvatarTimer(); WatchUi.requestUpdate(); return; }
        if (endConfirm) {
            if (endYes) {
                controller.endedAt = Time.now().value();
                controller.dispatch(:END);
                controller.tick(mode == :DEMO ? virtualMs : System.getTimer() - origin);
            }
            endConfirm = false;
        } else if (ready()) {
            if (planScreen != null) { acceptPlan(); }
            else if (stage == -1) { stage = 8; quick = true; }
            else {
                if (stage == 5) { todayChoice = Recovery.suggestedChoice(energy, soreness, 1); }
                if (stage < 8) { stage++; } else { startSession(); }
            }
        } else if (controller.lifecycle == :COMPLETE) {
            if (feedbackStage == 0) {
                nextChoice = Recovery.suggestedChoice(energy, soreness, effort);
                feedbackStage = 1;
            } else if (feedbackStage == 1) {
                feedbackStage = 2;
            } else if (feedbackStage == 2) {
                var next = Recovery.nextGoal(controller.config[:goalSec], nextChoice);
                controller.summary[:energy] = energy;
                controller.summary[:soreness] = soreness;
                controller.summary[:effort] = effort;
                controller.summary[:nextGoalSec] = next;
                controller.summary[:routine] = routine;
                controller.saved = storage.save(controller.summary);
                // Lets the dashboard mark its suggestion as done. Added after
                // the local save so the stored record keeps its schema.
                if (planId != null) { controller.summary[:planId] = planId; }
                if (effort_meter.seconds > 0) {
                    controller.summary[:avgHr] = effort_meter.avgHr();
                    controller.summary[:avgSpeedMps] = effort_meter.avgSpeedMps();
                    controller.summary[:effSec] = effort_meter.seconds;
                }
                controller.summary[:fluidMl] = fluidMl;
                controller.summary[:carbsG] = carbsG;
                if (mode == :LIVE && next != null) {
                    config[:goalSec] = next;
                    configSaved = storage.saveConfig(config);
                }
                if(weekly!=null) { weekly.finish(controller.summary,mode); }
                sync.send(controller.summary, share);
                lastSummary = storage.load();
                feedbackStage = 3;
            } else {
                if(weekly!=null && weekly.pending!=null && !weekly.finish(controller.summary,mode)) { WatchUi.requestUpdate(); return; }
                controller.dispatch(:RESET); controller.tick(mode == :DEMO ? virtualMs : System.getTimer()-origin);
                controller = null; stage = -1; quick = false; share = false;
                planGoalSec = null; planId = null; planDemo = false; missionSession=false;
            }
        } else {
            controller.dispatch(controller.lifecycle == :PAUSED ? :RESUME : :PAUSE);
            controller.tick(mode == :DEMO ? virtualMs : System.getTimer()-origin);
        }
        publishLive();
        syncAvatarTimer(); WatchUi.requestUpdate();
    }
    function adjust(direction) {
        if (!activated) { return; }
        if (ready() && stage==9) { weekly.move(direction); WatchUi.requestUpdate(); return; }
        if (historyIndex >= 0) {
            var records = storage.history();
            if (records.size() > 0) { historyIndex = (historyIndex + direction + records.size()) % records.size(); }
        } else if (endConfirm) { endYes = !endYes; }
        else if (ready()) {
            if (stage == 0) {
                // Three explicit choices: live, standard replay, HR-loss replay.
                if (mode == :LIVE) { mode = :DEMO; scenario = direction > 0 ? :STANDARD : :LOSS; }
                else if ((scenario == :STANDARD && direction > 0) || (scenario == :LOSS && direction < 0)) {
                    scenario = scenario == :STANDARD ? :LOSS : :STANDARD;
                } else { mode = :LIVE; }
            }
            if (stage == 1) {
                var low = config[:hrLowBpm] + direction;
                if (low >= 40 && low < config[:recoverBpm]) { config[:hrLowBpm] = low; }
            }
            if (stage == 2) {
                var high = config[:hrHighBpm] + direction;
                if (high <= 220 && high - 5 > config[:hrLowBpm]) {
                    config[:hrHighBpm] = high; config[:recoverBpm] = high - 5;
                }
            }
            if (stage == 4) { energy = (energy + direction + 3) % 3; }
            if (stage == 5) { soreness = (soreness + direction + 3) % 3; }
            if (stage == 6) { todayChoice = 1 - todayChoice; }
            if (stage == 7) { share = !share; }
            // On the short review screen UP/DOWN is the sharing switch, so
            // live updates can be turned on without the step-by-step settings.
            if (stage == 8 && quick && planScreen == null) { share = !share; }
            if (stage == 3) {
                var goal = config[:goalSec] + direction * 60;
                if (goal >= 60 && goal <= 3600) { config[:goalSec] = goal; }
            }
        } else if (controller.lifecycle == :COMPLETE) {
            if (feedbackStage == 0) { effort = (effort + direction + 4) % 4; }
            else if (feedbackStage == 1) { nextChoice = (nextChoice + direction + 3) % 3; }
            else if (feedbackStage == 2) { routine = (routine + direction + 4) % 4; }
            else { summaryPage = 1 - summaryPage; }
        }
        else if (controller.lifecycle == :ACTIVE) {
            metricsPage = !metricsPage;
        }
        syncAvatarTimer(); WatchUi.requestUpdate();
    }
    function menu() {
        if (!activated) { return; }
        if(ready() && stage==9) { weekly.menu(); WatchUi.requestUpdate(); return; }
        var m=new WatchUi.Menu2({:title=>"PacePilot tasks"});
        if (ready()) {
            m.addItem(new WatchUi.MenuItem("Weekly adventure", "Missions and saved progress", :missions, {}));
            m.addItem(new WatchUi.MenuItem("Get today's plan", "From your dashboard", :plan, {}));
            m.addItem(new WatchUi.MenuItem("Change settings", "Goal, HR band, sharing", :setup, {}));
            m.addItem(new WatchUi.MenuItem("Drink reminders", Fuel.modeLabel(drinkMode), :drinkmode, {}));
            m.addItem(new WatchUi.MenuItem("Local history", null, :history, {}));
            m.addItem(new WatchUi.MenuItem("Open Gut Train", "Exits PacePilot", :switch, {}));
        } else if (controller.lifecycle == :COMPLETE) {
            m.addItem(new WatchUi.MenuItem("Return to feedback", null, :close, {}));
            if (feedbackStage == 3) {
                m.addItem(new WatchUi.MenuItem("Retry sharing", null, :share, {}));
                m.addItem(new WatchUi.MenuItem("Open Gut Train", "Exits PacePilot", :switch, {}));
            }
        } else {
            m.addItem(new WatchUi.MenuItem("Log drink", Fuel.SIP_ML + " ml", :drink, {}));
            m.addItem(new WatchUi.MenuItem("Log food", Fuel.PORTION_G + " g carbs", :food, {}));
            m.addItem(new WatchUi.MenuItem("Workout metrics", null, :metrics, {}));
            m.addItem(new WatchUi.MenuItem("Walk now", null, :walk, {}));
            if (controller.decision[:advice] == :READY_TO_RUN && missionAllowsRunning()) {
                m.addItem(new WatchUi.MenuItem("Accept running", "Offered now", :run, {}));
            }
            m.addItem(new WatchUi.MenuItem("Finish workout", "Confirm before ending", :finish, {}));
            m.addItem(new WatchUi.MenuItem("Open Gut Train", "Finish workout first", :blocked, {}));
        }
        onHide(); // Stop redraws before the native menu covers this view.
        WatchUi.pushView(m,new TaskMenuDelegate(self),WatchUi.SLIDE_IMMEDIATE);
    }
    function task(id) {
        if(id==:missions && ready()) {
            if(weekly==null) { weekly=new PaceWeekly(new RaceForgeStoragePort()); }
            weekly.cancel(); weekly.open(mode); planGoalSec=null; planId=null; planDemo=false; stage=9; planScreen=null; historyIndex=-1;
        }
        if (id == :setup) { if(weekly!=null) { weekly.cancel(); } planGoalSec=null; planId=null; planDemo=false; stage=0; quick=false; historyIndex=-1; planScreen=null; }
        if (id == :plan && ready()) { if(weekly!=null) { weekly.cancel(); } planGoalSec=null; planId=null; planDemo=false; requestPlan(); }
        if (id == :history) { historyIndex=0; }
        if (id == :drinkmode) { drinkMode = (drinkMode + 1) % 5; }
        if (id == :drink && controller != null && controller.lifecycle != :COMPLETE) {
            fluidMl += Fuel.SIP_ML; lastDrinkSec = controller.sessionSec; drinkDue = false;
        }
        if (id == :food && controller != null && controller.lifecycle != :COMPLETE) { carbsG += Fuel.PORTION_G; }
        if (id == :metrics) { metricsPage=!metricsPage; }
        if (id == :walk && controller.lifecycle == :ACTIVE) { controller.dispatch(:WALK_NOW); }
        if (id == :run && controller.lifecycle == :ACTIVE && missionAllowsRunning()) { controller.dispatch(:ACCEPT_RUN); }
        if (id == :finish || id == :blocked) { endConfirm=true; endYes=false; }
        if (id == :share) { sync.send(controller.summary,share); }
        if (id == :switch && (ready() || (controller.lifecycle == :COMPLETE && feedbackStage == 3))) { AppSwitch.openGut(); }
        syncAvatarTimer(); WatchUi.requestUpdate();
    }
    function back() {
        if (!activated) { shutdown(); return false; }
        if(ready() && stage==9) { if(!weekly.back()) { stage=-1; } WatchUi.requestUpdate(); return true; }
        if(ready() && stage==8 && quick && weekly!=null && weekly.pending!=null) {
            weekly.cancel(); planGoalSec=null; stage=9; weekly.screen=:PREVIEW; WatchUi.requestUpdate(); return true;
        }
        if (historyIndex >= 0) { historyIndex = -1; syncAvatarTimer(); WatchUi.requestUpdate(); return true; }
        if (endConfirm) { endConfirm = false; }
        else if (ready()) {
            if (planScreen != null) { planScreen = null; }
            else if (stage == -1) { shutdown(); return false; }
            else if (stage == 8 && quick) { stage = -1; }
            else if (stage > 0) { stage--; }
            else { stage = -1; }
        } else if (controller.lifecycle != :COMPLETE) { endConfirm = true; endYes = false; }
        else { summaryPage = 1-summaryPage; }
        syncAvatarTimer(); WatchUi.requestUpdate();
        return true;
    }
    function requestPlan() {
        planScreen = PlanOffer.waiting();
        demoTried = false;
        planSync.fetch(self, false);
    }
    function onPlan(code, data) {
        // Ignore a late answer if the user already left the plan screen.
        if (planScreen == null) { return; }
        var offer = PlanOffer.parse(code, data);
        // Connected, but no plan is shared yet: offer the labelled demo plan
        // so the flow can still be tried. Only when the dashboard answered.
        if (!offer[:ok] && code == 200 && !demoTried && planScreen.hasKey(:waiting)) {
            demoTried = true;
            planSync.fetch(self, true);
            return;
        }
        planScreen = offer;
        WatchUi.requestUpdate();
    }
    function acceptPlan() {
        if (planScreen[:ok]) {
            planGoalSec = planScreen[:goalSec];
            planDemo = planScreen[:demo] == true;
            // A demo plan is never reported back as a completed suggestion.
            planId = planDemo ? null : planScreen[:id];
            stage = 8; quick = true;
        }
        planScreen = null;
    }
    function avatarScreen() {
        return historyIndex < 0 && !endConfirm && !ready() &&
            (controller.lifecycle == :PAUSED || (controller.lifecycle == :ACTIVE && !metricsPage));
    }
    function syncAvatarTimer() {
        // Paused is a static rest pose; summary/setup deliberately remain text-only.
        var run = avatarVisible && avatarScreen() && controller.lifecycle == :ACTIVE;
        if (run && avatarTimer == null) {
            avatarLastReal = System.getTimer();
            avatarTimer = new Timer.Timer();
            avatarTimer.start(method(:onAvatarTick), 250, true);
        } else if (!run && avatarTimer != null) {
            avatarTimer.stop(); avatarTimer = null; avatarLastReal = null;
        }
    }
    function onAvatarTick() as Void {
        // This callback NEVER advances sensors, coaching, haptics or DEMO time.
        if (avatarVisible && avatarTimer != null && avatarScreen()) { WatchUi.requestUpdate(); }
    }
    function prepareAvatar(now) {
        var c = controller;
        var next = avatarBridge.model(c.features, c.decision, c.lifecycle, c.config, 0);
        if(missionSession && !missionAllowsRunning()) {
            next.canResumeRun=false;
            if(c.lifecycle==:ACTIVE && next.visualState!=:SENSOR_UNAVAILABLE) { next.motion=missionKind.equals("mobility") ? :IDLE : :WALK; }
            if(c.lifecycle==:ACTIVE && next.visualState!=:SENSOR_UNAVAILABLE &&
                (next.advice==:RUN_EASY || next.advice==:READY_TO_RUN)) {
                next.headline=missionKind.equals("mobility") ? "Gentle mobility" : "Walk comfortably";
            }
        }
        if (avatarModel == null || next.visualState != avatarModel.visualState ||
            next.decisionId != avatarModel.decisionId || next.motion != avatarModel.motion) {
            avatarElapsed = 0;
        } else if (avatarVisible && c.lifecycle == :ACTIVE && avatarLastReal != null && now >= avatarLastReal) {
            avatarElapsed += now - avatarLastReal;
        }
        avatarLastReal = now;
        avatarModel = next;
        avatarAnimator.apply(avatarModel, avatarElapsed);
        return avatarModel;
    }
    function onUpdate(dc) as Void {
        syncAvatarTimer();
        if (!avatarScreen()) {
            avatarSurface = null; avatarSurfaceTried = false;
            Presenter.render(dc, self); return;
        }
        // One retained frame, guarded by current free VM memory. The 8-bit
        // fenix7pro surface is 67,600 pixels; budget four bytes/pixel plus 64 KiB
        // headroom conservatively. Direct drawing is the low-memory fallback.
        if (!avatarSurfaceTried) {
            avatarSurfaceTried = true;
            if (System.getSystemStats().freeMemory > dc.getWidth()*dc.getHeight()*4 + 65536) {
                try {
                    var ref = Graphics.createBufferedBitmap({:width=>dc.getWidth(), :height=>dc.getHeight()});
                    avatarSurface = ref.get();
                } catch (e) { avatarSurface = null; }
            }
        }
        if (avatarSurface != null) {
            Presenter.render(avatarSurface.getDc(), self);
            dc.drawBitmap(0, 0, avatarSurface);
        } else { Presenter.render(dc, self); }
    }
}
