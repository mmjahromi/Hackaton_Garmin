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
            :movingSec, :unknownMotionSec, :hrValidSec, :walkPromptCount, :goalMet, :endedAt];
    }
    function names() {
        return ["schemaVersion", "goalSec", "hrLowBpm", "hrHighBpm", "recoverBpm",
            "easeAfterSec", "walkAfterSec", "recoverHoldSec", "minWalkSec",
            "clearEaseSec", "hrReacquireSec", "sessionId", "mode", "sessionSec",
            "movingSec", "unknownMotionSec", "hrValidSec", "walkPromptCount", "goalMet", "endedAt"];
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
        return s[:movingSec] <= s[:sessionSec] && s[:hrValidSec] <= s[:sessionSec] &&
            s[:unknownMotionSec] <= s[:sessionSec];
    }
    function load() {
        try {
            var s = decode(Application.Storage.getValue("pacepilot-summary"));
            if (validSummary(s)) { return s; }
        } catch (e) {}
        return null;
    }
    function save(summary) {
        if (summary[:mode] == :DEMO) { return true; }
        try {
            Application.Storage.setValue("pacepilot-summary", encode(summary));
            failed = false;
            return true;
        } catch (e) { failed = true; return false; }
    }
}
