import Toybox.Application;
import Toybox.Lang;

class SummaryStore {
    var failed = false;
    function initialize() {}
    // Storage accepts strings and scalar values, not runtime symbols.
    function keys() {
        return [:schemaVersion, :goalSec, :hrLowBpm, :hrHighBpm, :recoverBpm,
            :easeAfterSec, :walkAfterSec, :recoverHoldSec, :minWalkSec,
            :clearEaseSec, :hrReacquireSec, :sessionId, :mode, :sessionSec,
            :movingSec, :unknownMotionSec, :hrValidSec, :walkPromptCount, :goalMet, :endedAt, :energy, :soreness, :effort, :nextGoalSec, :routine];
    }
    function names() {
        return ["schemaVersion", "goalSec", "hrLowBpm", "hrHighBpm", "recoverBpm",
            "easeAfterSec", "walkAfterSec", "recoverHoldSec", "minWalkSec",
            "clearEaseSec", "hrReacquireSec", "sessionId", "mode", "sessionSec",
            "movingSec", "unknownMotionSec", "hrValidSec", "walkPromptCount", "goalMet", "endedAt", "energy", "soreness", "effort", "nextGoalSec", "routine"];
    }
    function encode(source) {
        var result = {};
        var fields = keys();
        var labels = names();
        for (var i = 0; i < fields.size(); i++) {
            var key = fields[i];
            if (source.hasKey(key)) {
                result[labels[i]] = key == :mode ? "LIVE" : source[key];
            }
        }
        return result;
    }
    function decode(raw) {
        if (!(raw instanceof Dictionary)) { return null; }
        var result = {};
        var fields = keys();
        var labels = names();
        for (var i = 0; i < fields.size(); i++) {
            var key = labels[i];
            if (raw.hasKey(key)) {
                result[fields[i]] = fields[i] == :mode ? ((raw[key] instanceof String && raw[key].equals("LIVE")) ? :LIVE : :DEMO) : raw[key];
            }
        }
        return result;
    }
    function loadConfig() {
        try {
            var c = decode(Application.Storage.getValue("pacepilot-config"));
            if (Config.valid(c)) { return c; }
        } catch (e) {}
        return Config.defaults();
    }
    function saveConfig(c) {
        try { Application.Storage.setValue("pacepilot-config", encode(c)); return true; }
        catch (e) { return false; }
    }
    function validSummary(s) {
        if (!(s instanceof Dictionary) || !s.hasKey(:schemaVersion) || s[:schemaVersion] != 1 ||
            !s.hasKey(:mode) || s[:mode] != :LIVE || !s.hasKey(:goalMet) || !(s[:goalMet] instanceof Boolean)) { return false; }
        var fields = [:sessionId, :goalSec, :sessionSec, :movingSec, :unknownMotionSec,
            :hrValidSec, :walkPromptCount, :endedAt];
        for (var i = 0; i < fields.size(); i++) {
            if (!s.hasKey(fields[i]) || !Contracts.numberIn(s[fields[i]], 0, 4102444800l)) { return false; }
        }
        var optional = [:energy, :soreness, :effort, :routine];
        var limits = [2, 2, 3, 3];
        for (var j = 0; j < optional.size(); j++) {
            if (s.hasKey(optional[j]) && (!(s[optional[j]] instanceof Number) || !Contracts.numberIn(s[optional[j]], 0, limits[j]))) { return false; }
        }
        if (s.hasKey(:nextGoalSec) && s[:nextGoalSec] != null && !Contracts.numberIn(s[:nextGoalSec], 60, 3600)) { return false; }
        return s[:movingSec] <= s[:sessionSec] && s[:hrValidSec] <= s[:sessionSec] &&
            s[:unknownMotionSec] <= s[:sessionSec];
    }
    function load() {
        var records = history();
        if (records.size() > 0) { return records[0]; }
        try {
            var s = decode(Application.Storage.getValue("pacepilot-summary"));
            if (validSummary(s)) { return s; }
        } catch (e) {}
        return null;
    }
    function history() {
        try {
            var raw = Application.Storage.getValue("pacepilot-history");
            if (!(raw instanceof Array)) { return []; }
            var result = [];
            for (var i = 0; i < raw.size(); i++) {
                var s = decode(raw[i]);
                if (validSummary(s)) { result.add(s); }
            }
            return result;
        } catch (e) { return []; }
    }
    function save(summary) {
        if (summary[:mode] == :DEMO) { return true; }
        try {
            var records = history();
            var raw = [encode(summary)];
            for (var i = 0; i < records.size() && raw.size() < 20; i++) {
                if (records[i][:sessionId] != summary[:sessionId]) { raw.add(encode(records[i])); }
            }
            // The history is the primary record, updated idempotently by session ID.
            Application.Storage.setValue("pacepilot-history", raw);
            Application.Storage.setValue("pacepilot-summary", encode(summary));
            failed = false;
            return true;
        } catch (e) { failed = true; return false; }
    }
}
