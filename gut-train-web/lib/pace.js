const limits = {
  sessionId: [0, 4102444800], goalSec: [60, 3600], sessionSec: [0, 3600],
  movingSec: [0, 3600], unknownMotionSec: [0, 3600], hrValidSec: [0, 3600],
  walkPromptCount: [0, 10000], endedAt: [0, 4102444800],
};
const optional = { energy: [0, 2], soreness: [0, 2], effort: [0, 3], routine: [0, 3] };

function inRange(value, [min, max]) {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
}

export function normalizePaceSession(body) {
  if (!body || Array.isArray(body) || typeof body !== "object" ||
      body.schemaVersion !== 1 || !["LIVE", "DEMO"].includes(body.mode) ||
      typeof body.goalMet !== "boolean") throw new Error("Invalid PacePilot summary");
  const result = { schemaVersion: 1, mode: body.mode, goalMet: body.goalMet };
  for (const [key, range] of Object.entries(limits)) {
    if (!inRange(body[key], range)) throw new Error("Invalid " + key);
    result[key] = body[key];
  }
  if (!Number.isInteger(result.sessionId) || result.sessionSec > result.goalSec ||
      result.movingSec + result.unknownMotionSec > result.sessionSec ||
      result.hrValidSec > result.sessionSec ||
      (result.goalMet && result.sessionSec < result.goalSec)) {
    throw new Error("Inconsistent session totals");
  }
  for (const [key, range] of Object.entries(optional)) {
    const value = body[key] ?? null;
    if (value !== null && (!Number.isInteger(value) || !inRange(value, range))) throw new Error("Invalid " + key);
    result[key] = value;
  }
  // Links a completed session to the dashboard suggestion it carried out.
  // Food and drink logged from PacePilot's workout menu.
  for (const [key, max] of [["fluidMl", 30000], ["carbsG", 5000]]) {
    if (body[key] != null) {
      if (!Number.isInteger(body[key]) || body[key] < 0 || body[key] > max) throw new Error("Invalid " + key);
      result[key] = body[key];
    }
  }
  // Averages over the seconds the watch had both a heart rate and a moving
  // speed. All three arrive together or not at all.
  if (body.avgHr != null || body.avgSpeedMps != null || body.effSec != null) {
    if (!Number.isInteger(body.avgHr) || body.avgHr < 30 || body.avgHr > 250) throw new Error("Invalid avgHr");
    if (!inRange(body.avgSpeedMps, [0.1, 15])) throw new Error("Invalid avgSpeedMps");
    if (!Number.isInteger(body.effSec) || body.effSec < 1 || body.effSec > 3600) throw new Error("Invalid effSec");
    result.avgHr = body.avgHr; result.avgSpeedMps = body.avgSpeedMps; result.effSec = body.effSec;
  }
  if (body.planId != null) {
    if (typeof body.planId !== "string" || !/^[A-Za-z0-9_:.-]{1,64}$/.test(body.planId)) throw new Error("Invalid planId");
    result.planId = body.planId;
  }
  result.nextGoalSec = body.nextGoalSec ?? null;
  if (result.nextGoalSec !== null && !inRange(result.nextGoalSec, [60, 3600])) throw new Error("Invalid next goal");
  return result;
}

export function paceOverview(sessions) {
  const live = sessions.filter(session => session.mode === "LIVE");
  return {
    sessions: live.length,
    completed: live.filter(session => session.goalMet).length,
    minutes: Math.round(live.reduce((sum, session) => sum + session.sessionSec, 0) / 60),
    latest: live[0] ?? null,
  };
}
