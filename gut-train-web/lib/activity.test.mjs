import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const source = await readFile(new URL('./activity.js', import.meta.url), 'utf8');
const { weekDates, weekSummary, activityInsights, activityPlan } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const day = (date, overrides = {}) => ({ date, activeMin: 30, dailyTarget: 30, weekTarget: 150, nudges: 0, nudgesAnswered: 0, ...overrides });

test('Monday weeks cross year, leap day and DST boundaries without shifting', () => {
  assert.deepEqual(weekDates('2027-01-01'), ['2026-12-28', '2026-12-29', '2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02', '2027-01-03']);
  assert.equal(weekDates('2028-02-29')[0], '2028-02-28');
  assert.equal(weekDates('2027-03-14')[0], '2027-03-08');
  assert.equal(weekDates('2027-03-15')[0], '2027-03-15');
});

test('summary defaults and unordered records use newest current-week target and exclude future days', () => {
  assert.deepEqual(weekSummary([], '2027-01-01'), { minutes: 0, weekTarget: 150, daysHit: 0, streak: 0 });
  const days = [day('2026-12-28'), day('2027-01-02', { weekTarget: 300 }), day('2027-01-01', { activeMin: 10, weekTarget: 165 }), day('2026-12-27')];
  const before = JSON.stringify(days);
  assert.deepEqual(weekSummary(days, '2027-01-01'), { minutes: 40, weekTarget: 165, daysHit: 1, streak: 0 });
  assert.equal(JSON.stringify(days), before);
});

test('streak crosses weeks, includes today when met, otherwise starts yesterday, and breaks on gaps', () => {
  const days = ['2026-12-26', '2026-12-27', '2026-12-28'].map((date) => day(date));
  assert.equal(weekSummary(days, '2026-12-28').streak, 3);
  assert.equal(weekSummary(days, '2026-12-29').streak, 3);
  assert.equal(weekSummary([...days, day('2026-12-29', { activeMin: 5 })], '2026-12-29').streak, 3);
  assert.equal(weekSummary(days, '2026-12-30').streak, 0);
  assert.equal(weekSummary([days[0], days[2]], '2026-12-28').streak, 1);
  assert.equal(weekSummary([day('2026-12-28', { activeMin: 0, dailyTarget: 0 })], '2026-12-28').streak, 1);
});

test('activity prorates elapsed days and checks exact 80% and 100% thresholds', () => {
  for (const [activeMin, status] of [[79, 'fix'], [80, 'watch'], [99, 'watch'], [100, 'good'], [120, 'good']]) {
    const result = activityInsights([day('2026-12-29', { weekTarget: 350, activeMin })], '2026-12-29')[0];
    assert.equal(result.status, status);
    assert.match(result.detail, new RegExp(`${activeMin} active minutes.*100 min expected`));
    assert.deepEqual(Object.keys(result), ['area', 'status', 'title', 'detail']);
  }
  assert.equal(activityInsights([day('2027-01-03', { weekTarget: 70, activeMin: 70 })], '2027-01-03')[0].status, 'good');
  assert.equal(activityInsights([day('2026-12-28', { weekTarget: 0, activeMin: 0 })], '2026-12-28')[0].status, 'good');
  assert.deepEqual(activityInsights([], '2027-01-01'), []);
  assert.deepEqual(activityInsights([day('2027-01-02')], '2027-01-01'), []);
});

test('nudges cover last seven dates inclusive, skipping zero and respecting half answered', () => {
  for (const [nudges, nudgesAnswered, status] of [[4, 0, 'good'], [5, 2, 'watch'], [6, 3, 'good'], [5, 3, 'good']]) {
    const result = activityInsights([day('2027-01-01', { nudges, nudgesAnswered })], '2027-01-01');
    assert.equal(result.length, 2);
    assert.equal(result[1].status, status);
    assert.match(result[1].detail, new RegExp(`${nudgesAnswered} of ${nudges} nudges`));
    if (status === 'watch') assert.match(result[1].detail, /fixed walk after lunch or meetings/);
  }
  const result = activityInsights([
    day('2026-12-25', { nudges: 100 }), day('2026-12-26', { nudges: 5 }),
    day('2027-01-01', { nudges: 1, nudgesAnswered: 1 }), day('2027-01-02', { nudges: 100 }),
  ], '2027-01-01');
  assert.match(result[1].detail, /1 of 6 nudges/);
  assert.equal(activityInsights([day('2027-01-01')], '2027-01-01').length, 1);
});

test('daily plan divides first week, compounds 10%, rounds only final figures, and caps at 300/7', () => {
  assert.deepEqual(activityPlan(150, 6), [21, 24, 26, 29, 31, 35]);
  assert.deepEqual(activityPlan(280, 3), [40, 43, 43]);
  assert.deepEqual(activityPlan(10080, 2), [43, 43]);
  assert.deepEqual(activityPlan(150, 0), []);
  assert.deepEqual(activityPlan(0, 2), [0, 0]);
});
