import Toybox.System;
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
        if (v.avatarScreen()) {
            var label = v.controller.features[:mode] == :LIVE ? "LIVE" : "DEMO 4x";
            avatarText(dc, 14, label, tiny, accent);
        } else { line(dc, 27, v.mode == :LIVE ? "LIVE" : "DEMO 4x", tiny, accent); }
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
        if (v.ready() && v.planScreen != null) {
            var offer = v.planScreen;
            line(dc, 60, "Today's plan", tiny, grey);
            line(dc, 92, offer[:text], small, offer[:ok] ? accent : white);
            var detail = PlanOffer.wrap(offer[:detail], 24);
            line(dc, 128, detail[0], tiny, grey);
            line(dc, 150, detail[1], tiny, grey);
            line(dc, 187, offer[:ok] ? "START use it" : "BACK returns", tiny, white);
            line(dc, 213, offer[:ok] ? "BACK keeps yours" : "Nothing changed", tiny, grey);
            return;
        }
        if (v.ready() && v.stage == -1) {
            var goalSec = v.mode == :DEMO ? 180 : (v.planGoalSec != null ? v.planGoalSec : v.config[:goalSec]);
            line(dc, 62, "Today", small, grey);
            line(dc, 98, (goalSec / 60).toString() + " min run/walk", large, white);
            line(dc, 134, v.planId != null ? "From your dashboard plan" : "Easy pace. Walks count.", tiny, accent);
            line(dc, 178, "START begin", small, white);
            line(dc, 210, "Hold UP for options", tiny, grey);
            return;
        }
        if (v.ready() && v.stage == 8 && v.quick) {
            var reviewGoal = v.mode == :DEMO ? 180 : (v.planGoalSec != null ? v.planGoalSec : v.config[:goalSec]);
            line(dc, 58, "Ready?", small, white);
            line(dc, 92, (reviewGoal / 60).toString() + " min", large, accent);
            line(dc, 126, "HR band " + shown(v.config[:hrLowBpm]) + "-" + shown(v.config[:hrHighBpm]) + " bpm", tiny, white);
            line(dc, 150, v.share ? "Sharing: public demo site" : "Sharing: off", tiny, grey);
            line(dc, 187, "START begin / BACK", tiny, white);
            line(dc, 213, "Hold UP to change", tiny, grey);
            return;
        }
        if (v.ready()) {
            var titles = ["Choose mode", "Example HR low", "Example HR high", "Session goal", "Energy today", "Soreness today", "Today's session", "Share live + summary?", "Confirm settings"];
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
                line(dc, 213, "Live HR visible publicly", tiny, grey);
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
            var resting = v.prepareAvatar(System.getTimer());
            var w = dc.getWidth(); var h = dc.getHeight();
            v.avatarRenderer.draw(dc, resting, w*87/260, h*44/260, w*85/260, h*85/260);
            avatarText(dc, 134, "Paused", Graphics.FONT_SMALL, white);
            avatarText(dc, 163, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), tiny, white);
            avatarText(dc, 188, "START resumes", tiny, grey);
            avatarText(dc, 211, "BACK end session", tiny, grey);
            return;
        }
        var f = c.features;
        if (v.metricsPage) {
            line(dc, 49, "Session progress", small, white);
            line(dc, 77, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), small, accent);
            line(dc, 104, "Est. moving " + timeText(c.movingSec), tiny, white);
            line(dc, 128, f[:movement] == :UNKNOWN ? "Motion unknown" : (f[:movement] == :STILL ? "Stopped? Pause to rest" : "Movement estimated"), tiny, grey);
            line(dc, 152, f[:speedMps] == null ? "Speed -- m/s" : "Speed " + f[:speedMps].format("%.1f") + " m/s", tiny, white);
            line(dc, 176, v.liveFeed.status, tiny, grey);
            var sources = f[:sourceStatus];
            line(dc, 200, "HR " + badge(sources[:hr]) + "  GPS " + badge(sources[:speed]), tiny, grey);
            line(dc, 223, "ACC " + badge(sources[:motionRms]) + "  BAR " + badge(sources[:pressure]), tiny, grey);
            return;
        }
        var band=HrFeedback.state(f[:hrBpm],f[:hrReady],c.config[:hrLowBpm],c.config[:hrHighBpm]);
        accent=HrFeedback.color(band,Toybox.System.getTimer());
        var model = v.prepareAvatar(System.getTimer());
        var width = dc.getWidth(); var height = dc.getHeight();
        // Same prototype composition, with extra room for the explicit run-offer hint.
        avatarText(dc, 38, model.workoutText, tiny, grey);
        var offered = model.advice == :READY_TO_RUN && model.canResumeRun && model.visualState != :SENSOR_UNAVAILABLE;
        if (offered) { avatarText(dc, 59, "MENU offers run option", tiny, grey); }
        var size = width * (offered ? 82 : 104) / 260;
        v.avatarRenderer.draw(dc, model, (width-size)/2, height*(offered ? 80 : 60)/260, size, size);
        avatarText(dc, 166, model.dataText, tiny, 0x00AAAA);
        var headline = avatarHeadline(model, f);
        avatarText(dc, 190, headline, headlineFont(dc, headline, height*190/260), white);
        avatarText(dc, 218, timeText(c.sessionSec) + " / " + timeText(c.config[:goalSec]), tiny, grey);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT); dc.setPenWidth(3);
        var sweep = 360*c.sessionSec/c.config[:goalSec];
        if (sweep > 0) { dc.drawArc(width/2,height/2,(width < height ? width : height)/2-4,Graphics.ARC_CLOCKWISE,90,90-sweep); }
        dc.setPenWidth(1);
    }
    function avatarHeadline(model, features) {
        if (model.visualState == :SENSOR_UNAVAILABLE) { return "HR unavailable"; }
        if (model.advice == :READY_TO_RUN && model.canResumeRun) { return "Try running?"; }
        if (features[:movement] == :STILL) { return "Stopped? Pause to rest"; }
        if (model.advice == :EASE_OFF && features[:terrain] == :UP) { return "Ease off: Climb likely"; }
        return model.headline;
    }
    // Prototype's circular font-box check, with clearance inside the progress arc.
    function textFitsCircle(dc, text, font, y) {
        var half = (dc.getTextWidthInPixels(text, font)+1)/2;
        var cy = dc.getHeight()/2;
        var above = cy-y;
        var below = y+dc.getFontHeight(font)-cy;
        var dy = above > below ? above : below;
        var diameter = dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight();
        var radius = diameter/2-8;
        return half*half + dy*dy <= radius*radius;
    }
    function headlineFont(dc, text, y) {
        return dc.getFontHeight(Graphics.FONT_TINY) <= 26 && textFitsCircle(dc,text,Graphics.FONT_TINY,y) ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
    }
    function avatarText(dc, designY, text, font, color) {
        var y = dc.getHeight()*designY/260;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2,y,font,text,Graphics.TEXT_JUSTIFY_CENTER);
    }

}
