import test from 'node:test';
import assert from 'node:assert/strict';
import { buildPlan, normalizeDecision, shiftDate } from './plan.js';
import { estimateEnergy } from './energy.js';
import { normalizeProfile } from './profile.js';
import { normalizeMeal, mealsOn, normalizeBeat } from './meals.js';
import { watchConfig, demoWatchConfig } from './watchConfig.js';
import { demoProfile, demoSessions, demoMeals } from './demo.js';
import { loadOverview, resolveToday } from './overview.js';
import { normalizePaceSession } from './pace.js';

const TODAY = '2026-11-14'; // a Saturday
const ALL_DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const profile = (extra = {}) => ({ goal: 'stay_active', activities: ['run_walk', 'walk'], days: ALL_DAYS, durationMin: 20,
  experience: 'returning', ageYears: null, heightCm: null, weightKg: null, sexForEstimate: null, dayActivity: null,
  shareToWatch: false, updatedAt: Date.parse('2026-10-01') / 1000, demo: false, ...extra });
const session = (offset, extra = {}) => {
  const endedAt = Date.parse(shiftDate(TODAY, offset) + 'T17:00:00Z') / 1000;
  return { mode: 'LIVE', sessionId: endedAt - 1200, endedAt, sessionSec: 1200, goalSec: 1200, effort: 1, energy: 1, soreness: 0, ...extra };
};
const plan = (sessions, extra = {}) => buildPlan({ profile: profile(), sessions, decisions: [], today: TODAY, ...extra });

test('no profile gives no workout and says why', () => {
  const result = buildPlan({ profile: null, sessions: [], today: TODAY });
  assert.equal(result.suggestion.kind, 'rest');
  assert.match(result.suggestion.reason, /preferences/);
});

test('three manageable sessions offer a modest increase, as an offer only', () => {
  const result = plan([session(-1), session(-2, { effort: 0 }), session(-3)]);
  assert.equal(result.suggestion.durationMin, 20); // 22 rounds to the nearest 5
  assert.equal(result.suggestion.status, 'suggested');
  const longer = buildPlan({ profile: profile({ durationMin: 30 }), sessions: [session(-1), session(-2), session(-3)], today: TODAY });
  assert.equal(longer.suggestion.durationMin, 35);
  assert.match(longer.suggestion.reason, /little longer/);
  assert.ok(longer.suggestion.basis.some(line => /only an offer/.test(line)));
});

test('the increase is capped at usual + 15 and never above 90', () => {
  const sessions = [session(-1), session(-2), session(-3)];
  assert.equal(buildPlan({ profile: profile({ durationMin: 90 }), sessions, today: TODAY }).suggestion.durationMin, 90);
});

test('a too-hard session, high soreness or low energy offers a shorter, gentler session', () => {
  for (const extra of [{ effort: 2 }, { soreness: 2 }, { energy: 0 }]) {
    const result = plan([session(-1, extra), session(-2), session(-3)]);
    assert.equal(result.suggestion.durationMin, 15);
    assert.equal(result.suggestion.activity, 'walk');
    assert.match(result.suggestion.reason, /easier/);
  }
});

test('two missed planned days in a row offer a restart with no catch-up', () => {
  const result = plan([session(-3), session(-4), session(-5)]);
  assert.equal(result.suggestion.durationMin, 12);
  assert.match(result.suggestion.reason, /Restart/);
  assert.ok(result.suggestion.basis.includes('No catch-up needed'));
});

test('a brand-new profile is not told it missed days before it existed', () => {
  const fresh = profile({ updatedAt: Date.parse(TODAY + 'T09:00:00Z') / 1000 });
  const result = buildPlan({ profile: fresh, sessions: [], decisions: [], today: TODAY });
  assert.equal(result.suggestion.durationMin, 20);
  assert.match(result.suggestion.reason, /usual/);
  const edited = buildPlan({ profile: { ...fresh, createdAt: Date.parse('2026-10-01') / 1000 }, sessions: [], decisions: [], today: TODAY });
  assert.match(edited.suggestion.reason, /Restart/);
});

test('heart rate never raises a suggestion', () => {
  const calm = plan([session(-1, { hrValidSec: 1200, avgHr: 95 })]);
  const none = plan([session(-1, { hrValidSec: 0 })]);
  assert.equal(calm.suggestion.durationMin, none.suggestion.durationMin);
});

test('an unplanned day suggests rest with an optional short walk', () => {
  const result = buildPlan({ profile: profile({ days: ['mon'] }), sessions: [], today: TODAY });
  assert.equal(result.suggestion.kind, 'rest');
  assert.equal(result.suggestion.durationMin, 10);
});

test('decisions: accept, adjust, easier, rest and reschedule are explicit and validated', () => {
  const current = plan([session(-1)]).suggestion;
  assert.equal(normalizeDecision({ id: current.id, action: 'accept' }, current, TODAY).suggestion.status, 'accepted');
  const adjusted = normalizeDecision({ id: current.id, action: 'adjust', durationMin: 10, activity: 'walk' }, current, TODAY).suggestion;
  assert.deepEqual([adjusted.durationMin, adjusted.activity, adjusted.status], [10, 'walk', 'adjusted']);
  assert.equal(normalizeDecision({ id: current.id, action: 'easier' }, current, TODAY).suggestion.durationMin, 15);
  assert.equal(normalizeDecision({ id: current.id, action: 'rest' }, current, TODAY).suggestion.kind, 'rest');
  assert.equal(normalizeDecision({ id: current.id, action: 'reschedule', toDate: '2026-11-15' }, current, TODAY).suggestion.date, '2026-11-15');
  assert.throws(() => normalizeDecision({ id: 'other', action: 'accept' }, current, TODAY));
  assert.throws(() => normalizeDecision({ id: current.id, action: 'reschedule', toDate: TODAY }, current, TODAY));
  assert.throws(() => normalizeDecision({ id: current.id, action: 'adjust' }, current, TODAY));
  assert.throws(() => normalizeDecision({ id: current.id, action: 'harder' }, current, TODAY));
});

test('an accepted decision is what the plan then shows', () => {
  const first = plan([session(-1)]);
  const decision = normalizeDecision({ id: first.suggestion.id, action: 'adjust', durationMin: 10 }, first.suggestion, TODAY);
  const next = plan([session(-1)], { decisions: [decision] });
  assert.deepEqual([next.suggestion.durationMin, next.suggestion.status], [10, 'adjusted']);
});

test('a session carrying the plan id marks the suggestion done', () => {
  const first = plan([session(-1)]);
  const done = plan([session(0, { planId: first.suggestion.id }), session(-1)]);
  assert.equal(done.suggestion.status, 'done');
});

test('energy estimate matches Mifflin-St Jeor by hand and is a range', () => {
  // 10*70 + 6.25*172 - 5*29 + 5 = 1635; x 1.2 = 1962
  const result = estimateEnergy(profile({ ageYears: 29, heightCm: 172, weightKg: 70, sexForEstimate: 'male', dayActivity: 'mostly_sitting' }));
  assert.deepEqual([result.available, result.restingKcal, result.kcal], [true, 1635, 1962]);
  assert.deepEqual(result.rangeKcal, { min: 1766, max: 2158 });
  // 10*60 + 6.25*165 - 5*40 - 161 = 1270.25; x 1.375 = 1746.59
  const second = estimateEnergy(profile({ ageYears: 40, heightCm: 165, weightKg: 60, sexForEstimate: 'female', dayActivity: 'on_feet' }));
  assert.deepEqual([second.restingKcal, second.kcal], [1270, 1747]);
});

test('energy estimate refuses when details are missing or the user is under 18', () => {
  assert.equal(estimateEnergy(profile()).available, false);
  assert.deepEqual(estimateEnergy(profile({ ageYears: 30, heightCm: 170, weightKg: 70 })).missing, ['sexForEstimate', 'dayActivity']);
  const minor = estimateEnergy(profile({ ageYears: 16, heightCm: 170, weightKg: 60, sexForEstimate: 'male', dayActivity: 'on_feet' }));
  assert.equal(minor.available, false);
  assert.match(minor.reason, /18/);
});

test('profile validation: only stay_active, optional health details, explicit watch consent', () => {
  const base = { goal: 'stay_active', activities: ['walk'], days: ['mon', 'thu'], durationMin: 20, experience: 'new', shareToWatch: false };
  const saved = normalizeProfile(base, { now: 5 });
  assert.deepEqual([saved.ageYears, saved.weightKg, saved.shareToWatch, saved.updatedAt], [null, null, false, 5]);
  assert.throws(() => normalizeProfile({ ...base, goal: 'marathon' }));
  assert.throws(() => normalizeProfile({ ...base, activities: [] }));
  assert.throws(() => normalizeProfile({ ...base, durationMin: 5 }));
  assert.throws(() => normalizeProfile({ ...base, weightKg: '70' }));
  assert.throws(() => normalizeProfile({ ...base, shareToWatch: undefined }));
});

test('the watch only gets a plan with consent, and never a demo plan', () => {
  const current = plan([session(-1)]);
  assert.deepEqual(watchConfig(profile(), current), { schemaVersion: 1, available: false });
  assert.equal(watchConfig(profile({ shareToWatch: true, demo: true }), current).available, false);
  const shared = watchConfig(profile({ shareToWatch: true }), current, 99);
  assert.deepEqual([shared.available, shared.suggestion.durationMin, shared.updatedAt], [true, 20, 99]);
  assert.ok(shared.suggestion.reason.length <= 60);
});

test('meals and heartbeats are validated', () => {
  const meal = normalizeMeal({ date: TODAY, kcal: 450, label: ' Lunch ' }, { now: 100 });
  assert.deepEqual([meal.kcal, meal.label, meal.date, meal.demo], [450, 'Lunch', TODAY, false]);
  for (const kcal of [0, 5001, 12.5, '400', null, true]) assert.throws(() => normalizeMeal({ date: TODAY, kcal }));
  assert.throws(() => normalizeMeal({ date: '2026-02-30', kcal: 100 }));
  assert.deepEqual(mealsOn([meal, { ...meal, date: '2026-11-13', kcal: 900 }], TODAY).kcal, 450);
  assert.equal(normalizeBeat({ schemaVersion: 1, app: 'guttrain', at: 90, batteryPct: 80 }, 100).receivedAt, 100);
  assert.throws(() => normalizeBeat({ schemaVersion: 1, app: 'other', at: 90 }, 100));
  assert.throws(() => normalizeBeat({ schemaVersion: 1, app: 'guttrain', at: 500 }, 100));
});

test('demo history is reproducible, labelled, and yields a restart suggestion', () => {
  assert.deepEqual(demoSessions(TODAY), demoSessions(TODAY));
  const sessions = demoSessions(TODAY);
  assert.ok(sessions.every(s => s.demo === true && s.mode === 'DEMO'));
  assert.ok(sessions.some(s => s.effort === 2) && sessions.some(s => s.effort === 0));
  assert.ok(sessions.some(s => s.hrValidSec === 0), 'includes a session with no heart-rate reading');
  assert.ok(demoMeals(TODAY).every(meal => meal.demo === true));
  const result = buildPlan({ profile: demoProfile(TODAY), sessions, decisions: [], today: TODAY });
  assert.equal(result.demo, true);
  assert.equal(result.suggestion.durationMin, 15);
  assert.match(result.suggestion.reason, /Restart/);
  assert.equal(result.consistency.length, 14);
  assert.ok(result.consistency.some(day => day.planned && !day.done) && result.consistency.some(day => day.done));
});

test('demo and real data never mix in the overview', async () => {
  const calls = [];
  const store = {
    getProfile: async demo => { calls.push(['profile', demo]); return demo ? null : profile(); },
    listDecisions: async demo => { calls.push(['decisions', demo]); return []; },
    listMeals: async demo => { calls.push(['meals', demo]); return []; },
    listPaceSessions: async () => { calls.push(['real-sessions']); return [session(-1), { ...session(-2), mode: 'DEMO' }]; },
    listDays: async () => [], listLive: async () => [], listBeats: async () => [], listSessions: async () => [],
  };
  const demo = await loadOverview(store, { demo: true, today: TODAY, now: 1 });
  assert.ok(!calls.some(call => call[0] === 'real-sessions'), 'demo must not read real sessions');
  assert.ok(calls.every(call => call[1] === true));
  assert.equal(demo.watch, null);
  assert.ok(demo.recent.every(s => s.demo === true));
  calls.length = 0;
  const real = await loadOverview(store, { demo: false, today: TODAY, now: 1 });
  assert.ok(calls.filter(call => call.length === 2).every(call => call[1] === false));
  assert.deepEqual(real.recent.map(s => s.mode), ['LIVE']);
  assert.equal(real.mealsToday.kcal, 0);
  assert.equal(real.watch.connection.pacepilot.connected, false);
});

test('today follows the browser only within a day of the server', () => {
  const now = Date.parse('2026-11-14T03:00:00Z');
  assert.equal(resolveToday('2026-11-13', now), '2026-11-13');
  assert.equal(resolveToday('2026-11-01', now), '2026-11-14');
  assert.equal(resolveToday('nonsense', now), '2026-11-14');
});

test('the demo plan for the watch is always marked as a demo', () => {
  const demoPlan = buildPlan({ profile: demoProfile(TODAY), sessions: demoSessions(TODAY), decisions: [], today: TODAY });
  const config = demoWatchConfig(demoPlan, 7);
  assert.deepEqual([config.available, config.demo, config.suggestion.durationMin, config.updatedAt], [true, true, 15, 7]);
  assert.ok(config.suggestion.reason.length <= 60);
  // The real route never marks a plan as demo, and never serves one without consent.
  assert.equal(watchConfig(profile({ shareToWatch: true }), plan([session(-1)])).demo, undefined);
});

test('workout intake from PacePilot is validated and totalled for today', async () => {
  const base = { schemaVersion: 1, mode: 'LIVE', goalMet: false, sessionId: 5, goalSec: 1200, sessionSec: 600, movingSec: 500, unknownMotionSec: 0, hrValidSec: 500, walkPromptCount: 0, endedAt: 700 };
  const saved = normalizePaceSession({ ...base, fluidMl: 300, carbsG: 25 });
  assert.deepEqual([saved.fluidMl, saved.carbsG], [300, 25]);
  assert.equal('fluidMl' in normalizePaceSession(base), false);
  for (const bad of [{ fluidMl: -1 }, { carbsG: 12.5 }, { fluidMl: '300' }, { carbsG: 99999 }]) assert.throws(() => normalizePaceSession({ ...base, ...bad }));
  const store = {
    getProfile: async () => profile(), listDecisions: async () => [], listMeals: async () => [],
    listPaceSessions: async () => [session(0, { fluidMl: 300, carbsG: 25 }), session(-1, { fluidMl: 900 })],
    listDays: async () => [], listLive: async () => [], listBeats: async () => [],
    listSessions: async () => [{ at: Date.parse(TODAY + 'T10:00:00Z') / 1000, fluidMl: 150, carbsG: 50, demo: false }, { at: Date.parse(TODAY + 'T11:00:00Z') / 1000, fluidMl: 999, carbsG: 999, demo: true }],
  };
  const real = await loadOverview(store, { demo: false, today: TODAY, now: 1 });
  assert.deepEqual(real.workoutIntake, { fluidMl: 450, carbsG: 75 });
});

 test('rest choice can be replaced with an explicit activity goal', () => {
  const current = plan([session(-1)]).suggestion;
  const rest = normalizeDecision({ id: current.id, action: 'rest' }, current, TODAY).suggestion;
  const decision = normalizeDecision({ id: rest.id, action: 'adjust', durationMin: 30, activity: 'walk' }, rest, TODAY);
  const next = plan([session(-1)], { decisions: [decision] }).suggestion;
  assert.deepEqual([next.kind, next.activity, next.durationMin, next.status], ['workout', 'walk', 30, 'adjusted']);
  assert.throws(() => normalizeDecision({ id: next.id, action: 'adjust', durationMin: 30 }, {...next, status: 'done'}, TODAY));
});
