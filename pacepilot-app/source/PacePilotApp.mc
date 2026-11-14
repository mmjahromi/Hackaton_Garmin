import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;

class PacePilotApp extends Application.AppBase {
    var view;
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        view = new PacePilotView();
        return [view, new Delegate(view)];
    }
    function onStop(state) as Void { if (view != null) { view.shutdown(); } }
}

class PacePilotView extends WatchUi.View {
    var config;
    var storage;
    var controller = null;
    var alerts;
    var timer = null;
    var mode = :LIVE;
    var scenario = :STANDARD;
    var stage = 0;
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
    var historyIndex = -1;
    var lastSummary;
    function initialize() {
        View.initialize();
        storage = new SummaryStore();
        sync = new DashboardSync();
        config = storage.loadConfig();
        lastSummary = storage.load();
        alerts = new AlertService();
    }
    function onShow() as Void {
        if (timer == null) {
            timer = new Timer.Timer();
            timer.start(method(:onTick), 1000, true);
        }
    }
    function shutdown() {
        if (timer != null) { timer.stop(); timer = null; }
        if (controller != null) { controller.stop(); }
    }
    function ready() { return controller == null || controller.lifecycle == :READY; }
    function startSession() {
        if (!Config.valid(config)) { return; }
        sync = new DashboardSync();
        configSaved = storage.saveConfig(config);
        var c = Config.defaults();
        c[:hrLowBpm] = config[:hrLowBpm]; c[:hrHighBpm] = config[:hrHighBpm];
        c[:recoverBpm] = config[:recoverBpm];
        c[:goalSec] = mode == :DEMO ? 180 : Recovery.nextGoal(config[:goalSec], todayChoice);
        var provider = mode == :LIVE ? new LiveProvider() : new ReplayProvider(scenario);
        controller = new SessionController(c, provider, storage, mode);
        controller.sessionId = Time.now().value();
        origin = System.getTimer(); lastReal = origin; virtualMs = 0;
        alerts = new AlertService(); summaryPage = 0; feedbackStage = 0; effort = 1; routine = 0;
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
                        if (virtualMs == 160000) { controller.dispatch(:ACCEPT_RUN); }
                        controller.tick(virtualMs);
                        signal(realNow);
                    }
                }
            }
            lastReal = realNow;
            signal(realNow);
        }
        WatchUi.requestUpdate();
    }
    function signal(now) {
        if (controller.lifecycle == :ACTIVE && controller.features[:hrReady]) {
            var a = controller.decision[:advice];
            if (a == :EASE_OFF || a == :WALK || a == :READY_TO_RUN) {
                alerts.emit(controller.decision[:decisionId], a, now);
            }
        }
    }
    function select() {
        if (historyIndex >= 0) { historyIndex = -1; WatchUi.requestUpdate(); return; }
        if (endConfirm) {
            if (endYes) {
                controller.endedAt = Time.now().value();
                controller.dispatch(:END);
                controller.tick(mode == :DEMO ? virtualMs : System.getTimer() - origin);
            }
            endConfirm = false;
        } else if (ready()) {
            if (stage == 5) { todayChoice = Recovery.suggestedChoice(energy, soreness, 1); }
            if (stage < 8) { stage++; } else { startSession(); }
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
                if (mode == :LIVE && next != null) {
                    config[:goalSec] = next;
                    configSaved = storage.saveConfig(config);
                }
                sync.send(controller.summary, share);
                lastSummary = storage.load();
                feedbackStage = 3;
            } else {
                controller.dispatch(:RESET); controller.tick(mode == :DEMO ? virtualMs : System.getTimer()-origin);
                controller = null; stage = 0; share = false;
            }
        } else {
            controller.dispatch(controller.lifecycle == :PAUSED ? :RESUME : :PAUSE);
            controller.tick(mode == :DEMO ? virtualMs : System.getTimer()-origin);
        }
        WatchUi.requestUpdate();
    }
    function adjust(direction) {
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
            controller.dispatch(direction > 0 ? :WALK_NOW : :ACCEPT_RUN);
        }
        WatchUi.requestUpdate();
    }
    function menu() {
        if (ready()) {
            historyIndex = historyIndex >= 0 ? -1 : 0;
            WatchUi.requestUpdate();
        } else if (controller.lifecycle == :COMPLETE && feedbackStage == 3) {
            sync.send(controller.summary, share);
        } else if (controller.lifecycle == :ACTIVE) {
            metricsPage = !metricsPage;
            WatchUi.requestUpdate();
        }
    }
    function back() {
        if (historyIndex >= 0) { historyIndex = -1; WatchUi.requestUpdate(); return true; }
        if (endConfirm) { endConfirm = false; }
        else if (ready()) {
            if (stage > 0) { stage--; }
            else { shutdown(); return false; }
        } else if (controller.lifecycle != :COMPLETE) { endConfirm = true; endYes = false; }
        else { summaryPage = 1-summaryPage; }
        WatchUi.requestUpdate();
        return true;
    }
    function onUpdate(dc) as Void { Presenter.render(dc, self); }
}
