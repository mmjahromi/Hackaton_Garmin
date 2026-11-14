// Pure rules: no clock, storage, sensors, haptics, or rendering.
class CoachEngine {
    var config;
    function initialize(c) { config = c; }
    function initialMemory() {
        return {:advice=>:RUN_EASY, :highSec=>0.0, :lowSec=>0.0, :walkSec=>0.0,
            :decisionId=>0, :hrLost=>true};
    }
    function clearDwell(m) { m[:highSec] = 0.0; m[:lowSec] = 0.0; m[:walkSec] = 0.0; }
    function step(f, original, dt, event) {
        var m = {};
        var keys = original.keys();
        for (var i = 0; i < keys.size(); i++) { m[keys[i]] = original[keys[i]]; }
        var entry = m[:advice];
        var ready = f[:hrReady] && f[:hrBpm] != null;
        var low = ready && f[:hrBpm] <= config[:recoverBpm];
        m[:highSec] = ready && f[:hrBpm] > config[:hrHighBpm] ? m[:highSec] + dt : 0.0;
        m[:lowSec] = low ? m[:lowSec] + dt : 0.0;
        if (entry == :WALK || entry == :READY_TO_RUN) { m[:walkSec] += dt; }
        var reason = :COMFORTABLE;
        if (event == :WALK_NOW) {
            m[:advice] = :WALK; clearDwell(m); reason = :MANUAL_WALK;
        } else if (!ready) {
            if (entry == :READY_TO_RUN) { m[:advice] = :WALK; }
            clearDwell(m);
        } else if (entry == :READY_TO_RUN) {
            if (!low || f[:movement] == :STILL) { m[:advice] = :WALK; m[:lowSec] = 0.0; }
            else if (event == :ACCEPT_RUN) { m[:advice] = :RUN_EASY; clearDwell(m); }
        } else if (entry == :WALK) {
            if (m[:walkSec] >= config[:minWalkSec] && m[:lowSec] >= config[:recoverHoldSec] &&
                f[:movement] != :STILL) { m[:advice] = :READY_TO_RUN; }
        } else if (m[:highSec] >= config[:walkAfterSec]) {
            m[:advice] = :WALK; m[:walkSec] = 0.0; m[:lowSec] = 0.0;
        } else if (entry == :RUN_EASY && m[:highSec] >= config[:easeAfterSec]) {
            m[:advice] = :EASE_OFF;
        } else if (entry == :EASE_OFF && m[:lowSec] >= config[:clearEaseSec]) {
            m[:advice] = :RUN_EASY; clearDwell(m);
        }
        if (m[:advice] == :EASE_OFF) { reason = f[:terrain] == :UP ? :HIGH_HR_UPHILL : :HIGH_HR; }
        if (m[:advice] == :WALK && reason != :MANUAL_WALK) { reason = :WALK_BREAK; }
        if (m[:advice] == :READY_TO_RUN) { reason = :RECOVERED; }
        if (!ready) { reason = :HR_UNAVAILABLE; }
        else if (f[:movement] == :STILL && m[:advice] != :EASE_OFF && m[:advice] != :WALK) { reason = :STOPPED; }
        var lost = !ready;
        if (entry != m[:advice] || lost != m[:hrLost]) { m[:decisionId]++; }
        m[:hrLost] = lost;
        return {:memory=>m, :decision=>{:advice=>m[:advice], :reason=>reason,
            :decisionId=>m[:decisionId], :canResumeRun=>m[:advice] == :READY_TO_RUN && low && f[:movement] != :STILL}};
    }
}
