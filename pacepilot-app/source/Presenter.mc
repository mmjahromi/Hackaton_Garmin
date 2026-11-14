import Toybox.Graphics;
import Toybox.Math;

module Presenter {
    function line(dc, y, text, font, color) {
        // Bound each line to the round display, including its font height.
        var edge = (y >= 130 ? y - 130 : 130 - y) + 12;
        var width = edge >= 124 ? 0 : 2 * Math.sqrt(124*124 - edge*edge) - 12;
        if (dc.getTextWidthInPixels(text, font) > width) { font = Graphics.FONT_XTINY; }
        if (dc.getTextWidthInPixels(text, font) > width) {
            while (text.length() > 1 && dc.getTextWidthInPixels(text + "...", font) > width) {
                text = text.substring(0, text.length()-1);
            }
            text += "...";
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function timeText(seconds) {
        var s = seconds.toNumber();
        return (s / 60).format("%02d") + ":" + (s % 60).format("%02d");
    }
    function shown(value) { return value == null ? "--" : value.toNumber().toString(); }
    function badge(status) {
        if (status == :VALID) { return "ok"; }
        if (status == :STALE) { return "old"; }
        if (status == :UNSUPPORTED) { return "n/a"; }
        if (status == :ERROR) { return "err"; }
        return "--";
    }
    function render(dc, v) {
        dc.setColor(0x101820, 0x101820); dc.clear();
        var white = Graphics.COLOR_WHITE;
        var grey = Graphics.COLOR_LT_GRAY;
        var accent = 0x55DDBB;
        var tiny = Graphics.FONT_XTINY;
        var small = Graphics.FONT_SMALL;
        var large = Graphics.FONT_MEDIUM;
        line(dc, 27, v.mode == :LIVE ? "LIVE" : "DEMO 4x", tiny, accent);
        if (v.historyIndex >= 0) {
            var records = v.storage.history();
            line(dc, 70, "Recent sessions", small, white);
            if (records.size() == 0) { line(dc, 120, "No live sessions yet", tiny, grey); }
            else {
                var record = records[v.historyIndex % records.size()];
                line(dc, 105, "Session " + timeText(record[:sessionSec]), small, accent);
                var label = record.hasKey(:effort) ? ["Easy", "About right", "Too hard", "Skipped"][record[:effort]] : "Not rated";
                line(dc, 140, label, small, white);
                line(dc, 174, "UP / DOWN history", tiny, grey);
            }
            line(dc, 210, "START returns", tiny, white);
            return;
        }
        if (v.endConfirm) {
            line(dc, 85, "End session?", large, white);
            line(dc, 120, v.endYes ? "End selected" : "Cancel selected", small, accent);
            line(dc, 160, "UP / DOWN to choose", tiny, grey);
            line(dc, 192, "START confirms", tiny, white);
            return;
        }
        if (v.ready()) {
            var titles = ["Choose mode", "Example HR low", "Example HR high", "Session goal", "Energy today", "Soreness today", "Today's session", "Share summary?", "Confirm settings"];
            var values = [v.mode == :LIVE ? "Live sensors" : (v.scenario == :LOSS ? "Replay HR loss" : "Replay standard"),
                shown(v.config[:hrLowBpm]) + " bpm", shown(v.config[:hrHighBpm]) + " bpm",
                (v.config[:goalSec]/60).toString() + " min",
                ["Low", "Okay", "Good"][v.energy],
                ["None", "Some", "High"][v.soreness],
                timeText(Recovery.nextGoal(v.config[:goalSec], v.todayChoice)),
                v.share ? "Public demo site" : "Keep on watch",
                shown(v.config[:hrLowBpm]) + "-" + shown(v.config[:hrHighBpm]) + " bpm"];
            line(dc, 64, titles[v.stage], small, white);
            line(dc, 99, values[v.stage], large, accent);
            line(dc, 135, v.stage == 8 ? "Experimental rules" : "UP / DOWN adjusts", tiny, grey);
            if (v.stage == 7) {
                line(dc, 158, "gut-train-web.vercel.app", tiny, grey);
                line(dc, 187, "START confirms choice", tiny, white);
                line(dc, 213, "Summary visible publicly", tiny, grey);
                return;
            }
            line(dc, 158, v.mode == :DEMO ? "Replay goal 3 min" : "Walks count toward goal", tiny, grey);
            line(dc, 187, v.stage == 8 ? "START confirms + starts" : "START next / BACK", tiny, white);
            if (v.stage == 0 && v.lastSummary != null) {
                line(dc, 213, "Last: " + timeText(v.lastSummary[:sessionSec]), tiny, grey);
            } else { line(dc, 213, "Choose HR band", tiny, grey); }
            return;
        }
        var c = v.controller;
        if (c.lifecycle == :COMPLETE && v.feedbackStage < 3) {
            var titles = ["How manageable?", "Next session", "My after-run routine"];
            var choices = [
                ["Easy", "About right", "Too hard", "Skip rating"][v.effort],
                ["Repeat goal", "Five minutes shorter", "Choose later"][v.nextChoice],
                ["No reminder", "Meal routine", "Drink routine", "Rest routine"][v.routine]
            ];
            line(dc, 65, titles[v.feedbackStage], small, white);
            line(dc, 105, choices[v.feedbackStage], small, accent);
            var note = v.feedbackStage == 1 ? "Your choice / confirm" : "UP / DOWN adjusts";
            line(dc, 145, note, tiny, grey);
            if (v.feedbackStage == 1) {
                var next = Recovery.nextGoal(c.config[:goalSec], v.nextChoice);
                line(dc, 173, next == null ? "No goal change" : timeText(next) + " next goal", tiny, white);
            }
            line(dc, 207, "START confirms", tiny, white);
            return;
        }
        if (c.lifecycle == :COMPLETE) {
            line(dc, 61, c.summary[:goalMet] ? "Goal met" : "Ended early", large, accent);
            if (v.summaryPage == 0) {
                line(dc, 99, "Session " + timeText(c.sessionSec), small, white);
                line(dc, 131, "Est. moving " + timeText(c.movingSec), tiny, grey);
                line(dc, 157, "Motion unknown " + timeText(c.unknownMotionSec), tiny, grey);
            } else {
                var coverage = c.sessionSec > 0 ? (100*c.hrValidSec/c.sessionSec).toNumber() : 0;
                line(dc, 99, "HR coverage " + coverage + "%", small, white);
                line(dc, 131, "Walk prompts " + c.walkPromptCount, tiny, grey);
                line(dc, 157, c.mode == :DEMO ? "Simulated session" : (c.saved ? "Summary saved" : "Summary unsaved"), tiny, grey);
            }
            var routines = ["UP / DOWN details", "Follow your meal routine", "Follow your drink routine", "Make time to rest"];
            line(dc, 176, routines[v.routine], tiny, grey);
            line(dc, 197, v.sync.status, tiny, grey);
            line(dc, 220, "START returns", tiny, white);
            return;
        }
        if (c.lifecycle == :PAUSED) {
            line(dc, 82, "Paused", large, accent);
            line(dc, 119, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), small, white);
            line(dc, 158, "START resumes", small, grey);
            line(dc, 191, "BACK end session", tiny, grey);
            return;
        }
        var f = c.features;
        if (v.metricsPage) {
            line(dc, 65, "Session progress", small, white);
            line(dc, 100, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), small, accent);
            line(dc, 135, "Est. moving " + timeText(c.movingSec), tiny, white);
            line(dc, 162, f[:movement] == :UNKNOWN ? "Motion unknown" : (f[:movement] == :STILL ? "Stopped? Pause to rest" : "Movement estimated"), tiny, grey);
            line(dc, 190, f[:speedMps] == null ? "Speed -- m/s" : "Speed " + f[:speedMps].format("%.1f") + " m/s", tiny, white);
            line(dc, 214, "Hold UP returns", tiny, grey);
            return;
        }
        var action = "Run easy";
        var reason = "Keep it comfortable";
        if (c.decision[:advice] == :EASE_OFF) { action = "Ease off"; reason = f[:terrain] == :UP ? "Climb likely" : "HR above chosen band"; }
        if (c.decision[:advice] == :WALK) { action = "Walk break"; reason = "Take it comfortably"; }
        if (c.decision[:advice] == :READY_TO_RUN) { action = "Try running?"; reason = "UP accepts / your choice"; }
        if (!f[:hrReady]) { action = "HR unavailable"; reason = "Walk if needed"; }
        if (f[:movement] == :STILL) { reason = "Stopped? Pause to rest"; }
        line(dc, 61, action, large, white);
        line(dc, 90, reason, tiny, accent);
        line(dc, 123, "HR " + shown(f[:hrBpm]) + " bpm", small, white);
        line(dc, 151, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), tiny, grey);
        var s = f[:sourceStatus];
        line(dc, 177, "HR " + badge(s[:hr]) + "  GPS " + badge(s[:speed]), tiny, grey);
        line(dc, 198, "ACC " + badge(s[:motionRms]) + "  BAR " + badge(s[:pressure]), tiny, grey);
        line(dc, 221, f[:movement] == :UNKNOWN ? "Motion unknown" : "START pause", tiny, accent);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT); dc.setPenWidth(3);
        var sweep = 360*c.sessionSec/c.config[:goalSec];
        if (sweep > 0) { dc.drawArc(130,130,126,Graphics.ARC_CLOCKWISE,90,90-sweep); }
        dc.setPenWidth(1);
    }
}
