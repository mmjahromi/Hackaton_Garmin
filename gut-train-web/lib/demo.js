import { shiftDate } from './plan.js';
import { WEEKDAYS } from './profile.js';

// A reproducible two-week demo history, generated relative to "today" so it
// always reads as recent. No randomness. Every record is marked demo and is
// served from here, never written into real storage.
//
// The story: a returning exerciser plans four days a week, has a hard
// session with sore legs, eases back, then misses the last two planned days.
// The plan engine should therefore offer a short restart today.
const weekdayOf = date => WEEKDAYS[(new Date(date + 'T00:00:00Z').getUTCDay() + 6) % 7];
const PLANNED_OFFSETS = [0, -2, -4, -5]; // repeats weekly

// One row per session: day offset, minutes, goal minutes, effort (0 easy,
// 1 about right, 2 too hard), energy (0 low..2 good), soreness (0 none..2
// high), share of the session with a heart-rate reading, average heart rate
// (bpm) and average moving speed (m/s) over that share.
//
// The walking pace stays near 5.8 km/h while the average heart rate drifts
// down from 127 to 120, so the fitness trend has something real to show.
// One session is a much faster run/walk (left out of the trend as a
// different pace) and one has no heart-rate reading at all.
const SESSIONS = [
  [-13, 15, 15, 0, 1, 0, 0.95, 127, 1.55],  // unplanned easy walk
  [-12, 20, 20, 1, 1, 0, 0.95, 128, 1.60],
  [-11, 22, 25, 0, 2, 0, 0.90, 126, 1.62],
  [-10, 12, 12, 0, 1, 0, 0.90, 124, 1.58],  // unplanned easy walk
  [-9, 30, 30, 2, 1, 2, 0.92, 158, 2.35],   // too hard, sore afterwards, much faster pace
  [-8, 12, 12, 0, 1, 1, 0.85, 123, 1.60],   // unplanned recovery walk
  [-7, 15, 20, 1, 0, 1, 0, null, null],     // low energy; no heart-rate reading at all
  [-6, 10, 10, 0, 1, 0, 0.88, 121, 1.61],   // unplanned easy walk
  [-5, 25, 25, 0, 2, 0, 0.40, 120, 1.63],   // heart-rate reading lost for most of it
];                                          // -4 and -2 were planned and missed

export function demoProfile(today) {
  const days = [...new Set(PLANNED_OFFSETS.map(offset => weekdayOf(shiftDate(today, offset))))];
  return {
    goal: 'stay_active', activities: ['run_walk', 'walk'], days: WEEKDAYS.filter(day => days.includes(day)),
    durationMin: 25, experience: 'returning', ageYears: 29, heightCm: 172, weightKg: 70,
    sexForEstimate: 'male', dayActivity: 'mostly_sitting', shareToWatch: false,
    updatedAt: Math.floor(Date.parse(shiftDate(today, -14) + 'T00:00:00Z') / 1000), demo: true,
  };
}

export function demoSessions(today) {
  return SESSIONS.map(([offset, minutes, goal, effort, energy, soreness, hrShare, avgHr, speed]) => {
    const endedAt = Math.floor(Date.parse(shiftDate(today, offset) + 'T17:30:00Z') / 1000);
    const sessionSec = minutes * 60;
    const movingSec = Math.round(sessionSec * 0.9);
    const session = {
      schemaVersion: 1, mode: 'DEMO', demo: true, sessionId: endedAt - sessionSec, endedAt,
      goalSec: goal * 60, sessionSec, goalMet: minutes >= goal,
      movingSec, unknownMotionSec: Math.round(sessionSec * 0.05),
      hrValidSec: Math.round(sessionSec * hrShare), walkPromptCount: effort === 2 ? 3 : 1,
      effort, energy, soreness, routine: 0, nextGoalSec: null,
    };
    if (avgHr != null) {
      Object.assign(session, { avgHr, avgSpeedMps: speed, effSec: Math.round(sessionSec * hrShare), distanceM: Math.round(speed * movingSec) });
    }
    return session;
  }).sort((a, b) => b.endedAt - a.endedAt);
}

export function demoMeals(today) {
  const at = (offset, time) => Math.floor(Date.parse(shiftDate(today, offset) + `T${time}:00Z`) / 1000);
  return [
    [0, '13:10', 620, 'Lunch'], [0, '08:05', 430, 'Breakfast'],
    [-1, '19:30', 780, 'Dinner'], [-1, '12:45', 560, 'Lunch'], [-1, '07:50', 410, 'Breakfast'],
  ].map(([offset, time, kcal, label], index) => ({ id: `demo-${index}`, date: shiftDate(today, offset), kcal, label, at: at(offset, time), demo: true }));
}
