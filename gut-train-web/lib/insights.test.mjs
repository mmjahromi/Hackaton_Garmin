import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Load the ESM source without changing the app's CommonJS package setting.
const source = await readFile(new URL('./insights.js', import.meta.url), 'utf8');
const { buildInsights, buildPlan } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const today = '2027-01-01';
const goal = { event: 'full', raceDate: '2027-06-14', targetGph: 90 };
const base = { rateGph: 60, targetGph: 60, nextTargetGph: 70, gutRating: 4, durationS: 7200, fluidMl: 1200, avgHr: 140, userMaxHr: 200, carbsG: 120, calories: 1200 };
const area = (name, overrides = {}, selectedGoal = null) => buildInsights([{ ...base, ...overrides }], selectedGoal, today).find((item) => item.area === name);

test('empty sessions yield no insights; missing readings skip areas', () => {
  assert.deepEqual(buildInsights([], goal, today), []);
  assert.deepEqual(buildInsights([{}], null, today), []);
  for (const name of ['Fluid', 'Effort', 'Energy replaced']) {
    assert.equal(area(name, { fluidMl: null, avgHr: 0, calories: 0 }), undefined);
  }
  assert.equal(area('Effort', { userMaxHr: 0 }), undefined);
  assert.equal(area('Fluid', { durationS: 0 }), undefined);
});

test('most recent three real sessions take precedence; demos are the fallback', () => {
  const sessions = [{ ...base, demo: true, rateGph: 0 }, ...Array.from({ length: 3 }, () => ({ ...base })), { ...base, rateGph: 0 }];
  assert.equal(buildInsights(sessions, null, today)[0].status, 'good');
  assert.equal(buildInsights([sessions[0]], null, today)[0].status, 'fix');
  const result = buildInsights(sessions, goal, today);
  assert.equal(new Set(result.map((item) => item.area)).size, result.length);
  result.forEach((item) => assert.deepEqual(Object.keys(item), ['area', 'status', 'title', 'detail']));
});

test('fuelling compares averages and includes both rates and feed advice', () => {
  const low = area('Fuelling', { rateGph: 53 });
  assert.equal(low.status, 'fix');
  assert.match(low.detail, /53 g\/h.*60 g\/h/);
  assert.match(low.detail, /Take every feed when the watch prompts/);
  assert.equal(area('Fuelling', { rateGph: 54 }).status, 'good');
  const fuel = buildInsights([{ ...base, rateGph: 20, targetGph: 30 }, { ...base, rateGph: 88, targetGph: 90 }], null, today)[0];
  assert.equal(fuel.status, 'good');
  assert.match(fuel.detail, /54 g\/h.*60 g\/h/);
});

test('gut rating boundaries and flags include timing only when known', () => {
  assert.equal(area('Gut comfort', { gutRating: 2 }).status, 'fix');
  assert.match(area('Gut comfort', { gutRating: 2 }).detail, /Hold or lower.*drink-based/);
  assert.equal(area('Gut comfort', { gutRating: 3 }).status, 'watch');
  assert.equal(area('Gut comfort', { gutRating: 4 }).status, 'good');
  assert.match(area('Gut comfort', { gutEvents: 2, firstGutEventS: 1850 }).detail, /2 times.*31 minutes/);
  assert.doesNotMatch(area('Gut comfort', { gutEvents: 2, firstGutEventS: null }).detail, /minutes/);
  assert.match(area('Gut comfort', { gutEvents: 1, firstGutEventS: 0 }).detail, /0 minutes/);
  assert.doesNotMatch(area('Gut comfort', { gutEvents: 0, firstGutEventS: 500 }).detail, /flag/);
});

test('fluid rates use duration and respect 400 and 500 ml/h thresholds', () => {
  for (const [rate, status] of [[399, 'fix'], [400, 'watch'], [499, 'watch'], [500, 'good']]) {
    const result = area('Fluid', { fluidMl: rate * 2 });
    assert.equal(result.status, status);
    assert.match(result.detail, new RegExp(`${rate} ml per hour`));
    assert.match(result.detail, /common starting range, not a rule/);
  }
});

test('effort uses individual profile max heart rate, including exact boundaries', () => {
  for (const [avgHr, status] of [[118, 'watch'], [120, 'good'], [170, 'good'], [172, 'watch']]) {
    assert.equal(area('Effort', { avgHr }).status, status);
  }
  assert.match(area('Effort', { avgHr: 118 }).detail, /too easy/);
  assert.match(area('Effort', { avgHr: 172 }).detail, /harder than long-course race pace/);
});

test('energy replaced reports carb calories, burned calories and percentage', () => {
  const result = area('Energy replaced', { carbsG: 75, calories: 1000 });
  assert.equal(result.status, 'good');
  assert.match(result.detail, /300 kcal.*1000 kcal.*30%/);
  assert.equal(area('Energy replaced', { carbsG: 74, calories: 1000 }).status, 'watch');
});

test('short sessions prompt longer sessions only for long-course goals', () => {
  for (const event of ['half', 'full']) assert.equal(area('Session length', { durationS: 7199 }, { ...goal, event }).status, 'watch');
  assert.equal(area('Session length', {}, goal), undefined);
  assert.equal(area('Session length', { durationS: 3600 }, { ...goal, event: 'sprint' }), undefined);
  assert.equal(area('Session length', { durationS: 3600 }), undefined);
});

test('goal gap handles achieved targets, exact weeks, insufficient time and past races', () => {
  assert.equal(area('Goal gap'), undefined);
  assert.equal(area('Goal gap', { nextTargetGph: 90 }, goal).status, 'good');
  assert.equal(area('Goal gap', {}, { ...goal, raceDate: '2027-01-15' }).status, 'good');
  const gap = area('Goal gap', {}, { ...goal, raceDate: '2027-01-14' });
  assert.equal(gap.status, 'fix');
  assert.match(gap.detail, /2 gut-training sessions.*1 whole weeks/);
  const past = area('Goal gap', { nextTargetGph: 100 }, { ...goal, raceDate: '2026-12-31' });
  assert.equal(past.status, 'watch');
  assert.match(past.title, /has passed/);
  const real = buildInsights([{ ...base, demo: true, nextTargetGph: 100 }, base], goal, today).find((item) => item.area === 'Goal gap');
  assert.match(real.detail, /from 70 to 90/);
});

test('default plan starts seven days later at 50 and stops at 90', () => {
  const plan = buildPlan([], null, today);
  assert.deepEqual(plan.map((item) => item.targetGph), [50, 60, 70, 80, 90]);
  assert.equal(plan[0].date, '2027-01-08');
  assert.equal(plan[4].date, '2027-02-05');
  assert.equal(plan[0].durationMin, 120);
  assert.match(plan[0].focus, /Hold 50 g\/h/);
  assert.deepEqual(plan.map((item) => item.week), [1, 2, 3, 4, 5]);
});

test('plan starts from newest target, respects caps and does not mutate inputs', () => {
  const sessions = [{ ...base, nextTargetGph: 55 }];
  const before = JSON.stringify({ sessions, goal });
  assert.deepEqual(buildPlan(sessions, goal, today).map((item) => item.targetGph), [55, 65, 75, 85, 90]);
  assert.equal(buildPlan([{ nextTargetGph: 0 }], { ...goal, targetGph: 120 }, today).length, 6);
  assert.equal(buildPlan([{ nextTargetGph: 150 }], { ...goal, targetGph: 150 }, today)[0].targetGph, 120);
  assert.equal(buildPlan([{ nextTargetGph: 100 }], null, today)[0].targetGph, 90);
  assert.equal(JSON.stringify({ sessions, goal }), before);
});

test('event duration defaults and final-week rehearsal holds target at half duration', () => {
  for (const [event, minutes] of [['sprint', 60], ['olympic', 90], ['half', 150], ['full', 180]]) {
    assert.equal(buildPlan([], { ...goal, event }, today)[0].durationMin, minutes);
    const plan = buildPlan([], { ...goal, event, raceDate: '2027-01-18' }, today);
    assert.equal(plan.length, 2);
    assert.equal(plan[1].targetGph, plan[0].targetGph);
    assert.equal(plan[1].durationMin, minutes / 2);
    assert.match(plan[1].focus, /shorter race rehearsal/);
  }
});

test('plan excludes race day and past races, handles year rollover and is deterministic', () => {
  assert.deepEqual(buildPlan([], { ...goal, raceDate: '2027-01-08' }, today), []);
  assert.deepEqual(buildPlan([], { ...goal, raceDate: '2026-12-01' }, today), []);
  assert.equal(buildPlan([], null, '2026-12-30')[0].date, '2027-01-06');
  assert.deepEqual(buildPlan([], goal, today), buildPlan([], goal, new Date(`${today}T23:59:00Z`)));
});

test('heat uses temperature readings and fluid from the same sessions, with exact thresholds', () => {
  assert.equal(area('Heat', { avgTempC: 26 }), undefined);
  assert.equal(area('Heat', { avgTempC: 0 }), undefined);
  assert.equal(area('Heat', { avgTempC: 28, fluidMl: null }), undefined);
  assert.equal(area('Heat', { avgTempC: 28, durationS: 0 }), undefined);
  const low = area('Heat', { avgTempC: 27, fluidMl: 1198 });
  assert.equal(low.status, 'fix');
  assert.match(low.detail, /27 °C.*599 ml.*fluid and sodium.*thermometer reads warmer than the air/);
  assert.equal(area('Heat', { avgTempC: 27, fluidMl: 1200 }).status, 'good');
  const heat = buildInsights([
    { ...base, avgTempC: 26 }, { ...base, avgTempC: 28 }, { ...base, fluidMl: 0 },
  ], null, today).find((item) => item.area === 'Heat');
  assert.equal(heat.status, 'good');
  assert.match(heat.detail, /27 °C.*600 ml/);
});

test('climbing reports ascent per hour only with climbing and gut flags together', () => {
  assert.equal(area('Climbing', { ascentM: 600 }), undefined);
  assert.equal(area('Climbing', { ascentM: 599, gutEvents: 1 }), undefined);
  assert.equal(area('Climbing', { ascentM: 600, durationS: 0, gutEvents: 1 }), undefined);
  const climb = area('Climbing', { ascentM: 600, gutEvents: 1 });
  assert.equal(climb.status, 'watch');
  assert.match(climb.detail, /300 m.*per hour.*feeding before hills rather than on them/);
  assert.equal(buildInsights([{ ...base, ascentM: 600 }, { ...base, gutEvents: 1 }], null, today)
    .find((item) => item.area === 'Climbing'), undefined);
});

test('stops sums counts and minutes, linking flags only within stopped sessions', () => {
  assert.equal(area('Stops', { stops: 0, stoppedS: 0 }), undefined);
  assert.equal(area('Stops', { stops: 2 }), undefined);
  const sessions = [{ ...base, stops: 2, stoppedS: 240 }, { ...base, stops: 1, stoppedS: 120 }, { ...base, gutEvents: 1 }];
  const result = buildInsights(sessions, null, today).find((item) => item.area === 'Stops');
  assert.equal(result.status, 'good');
  assert.match(result.detail, /3 stops.*6 minutes stopped/);
  sessions[0].gutEvents = 1;
  const flagged = buildInsights(sessions, null, today).find((item) => item.area === 'Stops');
  assert.equal(flagged.status, 'watch');
  assert.match(flagged.detail, /may have been gut-related/);
});

test('intensity counts hard feeds and skips absent or zero readings', () => {
  assert.equal(area('Intensity', { hardFeeds: 0 }), undefined);
  const result = buildInsights([{ ...base, hardFeeds: 2 }, { ...base, hardFeeds: 3 }], null, today)
    .find((item) => item.area === 'Intensity');
  assert.equal(result.status, 'watch');
  assert.match(result.detail, /5 feeds were taken above 85%.*ease off for a minute before eating/);
});

test('all new areas use recent three real sessions, with demo fallback and one insight each', () => {
  const sensors = { ...base, avgTempC: 28, ascentM: 800, gutEvents: 1, stops: 2, stoppedS: 240, hardFeeds: 2 };
  const names = ['Heat', 'Climbing', 'Stops', 'Intensity'];
  const hidden = buildInsights([{ ...sensors, demo: true }, base, base, base, sensors], null, today);
  assert.equal(hidden.filter((item) => names.includes(item.area)).length, 0);
  const shown = buildInsights(Array.from({ length: 4 }, () => ({ ...sensors, demo: true })), null, today);
  for (const name of names) {
    const matches = shown.filter((item) => item.area === name);
    assert.equal(matches.length, 1);
    assert.deepEqual(Object.keys(matches[0]), ['area', 'status', 'title', 'detail']);
  }
  assert.match(shown.find((item) => item.area === 'Intensity').detail, /6 feeds/);
  assert.match(shown.find((item) => item.area === 'Stops').detail, /6 stops.*12 minutes/);
});
