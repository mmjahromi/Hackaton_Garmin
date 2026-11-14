import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const load = (source) => import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
// Exercise the real memory store without depending on local Redis credentials.
const storeSource = (await readFile(new URL('./store.js', import.meta.url), 'utf8'))
  .replace(/const redisUrl = .*;/, 'const redisUrl = null;')
  .replace(/const redisToken = .*;/, 'const redisToken = null;');
const storeUrl = `data:text/javascript;base64,${Buffer.from(storeSource).toString('base64')}`;
const store = await import(storeUrl);
const route = async (path) => load((await readFile(new URL(path, import.meta.url), 'utf8'))
  .replace('"../../../lib/store"', JSON.stringify(storeUrl)));
const sessions = await route('../app/api/sessions/route.js');
const goals = await route('../app/api/goal/route.js');
const request = (body, method = 'POST') => new Request('http://localhost/api', {
  method, headers: { 'Content-Type': 'application/json', ...(process.env.INGEST_KEY ? { 'x-api-key': process.env.INGEST_KEY } : {}) }, body: JSON.stringify(body),
});
const session = { durationS: 7200, carbsG: 120, targetGph: 60, rateGph: 60, gutRating: 4, nextTargetGph: 70 };
const optional = { calories: 20000, maxHr: 250, userMaxHr: 250, gutEvents: 200, firstGutEventS: 86400 };
const goal = { event: 'full', raceDate: '2028-02-29', targetGph: 90 };

test('optional readings accept bounds and existing whole-number rounding', async () => {
  for (const values of [optional, Object.fromEntries(Object.keys(optional).map((key) => [key, 0]))]) {
    assert.equal((await sessions.POST(request({ ...session, ...values }))).status, 201);
    const saved = (await store.listSessions())[0];
    for (const [key, value] of Object.entries(values)) assert.equal(saved[key], value);
  }
  await sessions.POST(request({ ...session, calories: 620.4, maxHr: '152' }));
  const saved = (await store.listSessions())[0];
  assert.equal(saved.calories, 620);
  assert.equal(saved.maxHr, 152);
});

test('missing and invalid optional readings are null and do not reject valid sessions', async () => {
  for (const invalid of [undefined, null, '', ' ', true, [], {}, -1, 90000, 'bad']) {
    const values = Object.fromEntries(Object.keys(optional).map((key) => [key, invalid]));
    assert.equal((await sessions.POST(request({ ...session, ...values }))).status, 201);
    const saved = (await store.listSessions())[0];
    for (const key of Object.keys(optional)) assert.equal(saved[key], null);
  }
  assert.equal((await sessions.POST(request({ ...session, gutRating: 9 }))).status, 400);
  assert.equal((await sessions.POST(request(null))).status, 400);
});

test('goal GET returns null initially and PUT round trips only goal fields', async () => {
  assert.deepEqual(await (await goals.GET()).json(), { goal: null });
  const response = await goals.PUT(request({ ...goal, extra: 'ignored' }, 'PUT'));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { goal });
  assert.deepEqual(await (await goals.GET()).json(), { goal });
  const copy = await store.getGoal();
  copy.targetGph = 40;
  assert.deepEqual(await store.getGoal(), goal);
});

test('goal validation rejects impossible dates, bad events and non-integer targets', async () => {
  for (const bad of [
    null, [], {}, { ...goal, event: 'other' },
    ...['2027-02-29', '2028-02-30', '2028-13-01', '2028-04-31', '2028-2-01', 'bad'].map((raceDate) => ({ ...goal, raceDate })),
    ...[29, 121, 60.5, '90', null].map((targetGph) => ({ ...goal, targetGph })),
  ]) assert.equal((await goals.PUT(request(bad, 'PUT'))).status, 400);
  assert.deepEqual(await store.getGoal(), goal);
  for (const event of ['sprint', 'olympic', 'half', 'full']) {
    for (const targetGph of [30, 120]) assert.equal((await goals.PUT(request({ ...goal, event, targetGph }, 'PUT'))).status, 200);
  }
});

test('nine Garmin fields accept boundaries, numeric strings and optional rounding', async () => {
  const ranges = { distanceM: [0, 500000], ascentM: [0, 20000], avgTempC: [-40, 60], maxTempC: [-40, 60], stops: [0, 500], stoppedS: [0, 86400], hardFeeds: [0, 200], avgCadence: [0, 250], hotDrinkPrompts: [0, 500] };
  for (const [field, [min, max]] of Object.entries(ranges)) {
    for (const value of [min, max, 0, '12', 12.4]) {
      assert.equal((await sessions.POST(request({ ...session, [field]: value }))).status, 201);
      assert.equal((await store.listSessions())[0][field], Math.round(Number(value)));
    }
    for (const value of [undefined, null, '', ' ', true, false, [], {}, 'bad', min - 1, max + 1]) {
      assert.equal((await sessions.POST(request({ ...session, [field]: value }))).status, 201);
      assert.equal((await store.listSessions())[0][field], null);
    }
  }
  await sessions.POST(request({ ...session, avgTempC: -12, maxTempC: '-3' }));
  const saved = (await store.listSessions())[0];
  assert.equal(saved.avgTempC, -12);
  assert.equal(saved.maxTempC, -3);
});

const days = await route('../app/api/days/route.js');
const daily = { date: '2028-02-29', steps: 10000, activeMin: 30, floors: 10, bodyBattery: null,
  dailyTarget: 25, weekTarget: 150, nudges: 5, nudgesAnswered: 2, recoveryDay: false, demo: true };

test('omitted temperatures stay null in stored and GET sessions; zero is a reading', async () => {
  await sessions.POST(request(session));
  const saved = (await (await sessions.GET()).json()).sessions[0];
  assert.equal(saved.avgTempC, null);
  assert.equal(saved.maxTempC, null);
  await sessions.POST(request({ ...session, avgTempC: 0, maxTempC: 0 }));
  const zero = (await (await sessions.GET()).json()).sessions[0];
  assert.equal(zero.avgTempC, 0);
  assert.equal(zero.maxTempC, 0);
});

test('days GET starts empty, POST upserts by date and ignores extra fields', async () => {
  assert.deepEqual(await (await days.GET()).json(), { days: [] });
  assert.equal((await days.POST(request({ ...daily, extra: 'ignored' }))).status, 201);
  assert.deepEqual(await (await days.GET()).json(), { days: [daily] });
  await days.POST(request({ ...daily, activeMin: 40 }));
  assert.deepEqual(await store.listDays(), [{ ...daily, activeMin: 40 }]);
  const copy = await store.listDays();
  copy[0].activeMin = 0;
  assert.equal((await store.listDays())[0].activeMin, 40);
});

test('day numbers strictly validate integers and ranges, booleans and real dates', async () => {
  const ranges = { steps: 100000, activeMin: 1440, floors: 500, bodyBattery: 100,
    dailyTarget: 1440, weekTarget: 10080, nudges: 100, nudgesAnswered: 100 };
  for (const [field, max] of Object.entries(ranges)) {
    for (const value of [0, max]) assert.equal((await days.POST(request({ ...daily, [field]: value }))).status, 201);
    for (const value of [undefined, '', '1', true, [], {}, -1, max + 1, 1.5, ...(field === 'bodyBattery' ? [] : [null])]) {
      assert.equal((await days.POST(request({ ...daily, [field]: value }))).status, 400, `${field}: ${value}`);
    }
  }
  for (const field of ['demo', 'recoveryDay']) {
    for (const value of [undefined, null, 0, 1, 'true', 'false']) assert.equal((await days.POST(request({ ...daily, [field]: value }))).status, 400);
    for (const value of [true, false]) assert.equal((await days.POST(request({ ...daily, [field]: value }))).status, 201);
  }
  for (const date of ['2027-02-29', '2028-02-30', '2028-04-31', '2028-13-01', '2028-2-01', 'bad', null]) {
    assert.equal((await days.POST(request({ ...daily, date }))).status, 400);
  }
  for (const body of [null, [], {}, 'bad']) assert.equal((await days.POST(request(body))).status, 400);
  assert.equal((await days.POST(new Request('http://localhost/api/days', { method: 'POST', headers: request(daily).headers, body: '{' }))).status, 400);
});

test('days require the configured ingest key', async () => {
  const previous = process.env.INGEST_KEY;
  process.env.INGEST_KEY = 'test-key';
  try {
    assert.equal((await days.POST(new Request('http://localhost/api/days', { method: 'POST', body: JSON.stringify(daily) }))).status, 401);
    assert.equal((await days.POST(request(daily))).status, 201);
  } finally {
    if (previous === undefined) delete process.env.INGEST_KEY;
    else process.env.INGEST_KEY = previous;
  }
});

test('memory keeps newest 60 dates, including out-of-order inserts and updates', async () => {
  globalThis.__gutTrainDays = new Map();
  const dates = Array.from({ length: 65 }, (_, i) => new Date(Date.UTC(2028, 0, i + 1)).toISOString().slice(0, 10));
  for (const date of dates.toReversed()) await store.upsertDay({ ...daily, date });
  await store.upsertDay({ ...daily, date: dates[64], activeMin: 55 });
  const saved = await store.listDays();
  assert.equal(saved.length, 60);
  assert.deepEqual(saved.map((day) => day.date), dates.slice(5).reverse());
  assert.equal(saved[0].activeMin, 55);
});

test('Redis days use one date-keyed hash and trim to newest 60', async () => {
  const hash = new Map();
  const commands = [];
  const original = await readFile(new URL('./store.js', import.meta.url), 'utf8');
  const redisSource = original.replace(/const redisUrl = .*;/, 'const redisUrl = "https://redis.test";')
    .replace(/const redisToken = .*;/, 'const redisToken = "test";')
    .replace('await fetch(redisUrl,', 'await globalThis.__dayRedisFetch(redisUrl,');
  globalThis.__dayRedisFetch = async (_url, options) => {
    const [command, key, ...args] = JSON.parse(options.body);
    commands.push(command);
    assert.equal(key, 'gut-train:days');
    let result;
    if (command === 'HSET') { hash.set(args[0], args[1]); result = 1; }
    else if (command === 'HKEYS') result = [...hash.keys()];
    else if (command === 'HVALS') result = [...hash.values()];
    else if (command === 'HDEL') { args.forEach((date) => hash.delete(date)); result = args.length; }
    else assert.fail(`Unexpected command ${command}`);
    return Response.json({ result });
  };
  try {
    const redisStore = await load(redisSource);
    const dates = Array.from({ length: 62 }, (_, i) => new Date(Date.UTC(2028, 0, i + 1)).toISOString().slice(0, 10));
    for (const date of dates.toReversed()) await redisStore.upsertDay({ ...daily, date });
    await redisStore.upsertDay({ ...daily, date: dates[61], activeMin: 99 });
    const saved = await redisStore.listDays();
    assert.deepEqual(saved.map((day) => day.date), dates.slice(2).reverse());
    assert.equal(saved[0].activeMin, 99);
    assert.equal(hash.size, 60);
    assert.ok(commands.includes('HDEL'));
  } finally { delete globalThis.__dayRedisFetch; }
});


test('nutrition logs preserve confirmed choices and filter invalid feed records', async () => {
  const feed = { atS: 120, carbsG: 25, kind: 'gel' };
  await sessions.POST(request({ ...session, foodType: 'gel', portionG: 25,
    drinkIntervalS: 0, targetConfirmed: true,
    fuelLog: [feed, { ...feed, secret: 'ignored' }, null, { ...feed, carbsG: -2 }] }));
  const saved = (await store.listSessions())[0];
  assert.deepEqual(saved.fuelLog, [feed, feed]);
  assert.equal(saved.targetConfirmed, true);
  assert.equal(saved.portionG, 25);
  assert.equal(saved.drinkIntervalS, 0);
  await sessions.POST(request({ ...session, foodType: 'unknown', targetConfirmed: 'true',
    fuelLog: Array.from({ length: 50 }, () => feed) }));
  const bounded = (await store.listSessions())[0];
  assert.equal(bounded.fuelLog.length, 32);
  assert.equal(bounded.foodType, null);
  assert.equal(bounded.targetConfirmed, false);
});


test('required nutrition numbers reject null, booleans, blanks and containers', async () => {
  for (const field of ['durationS','carbsG','targetGph','rateGph','gutRating','nextTargetGph']) {
    for (const invalid of [null, true, false, '', ' ', [], [50], {}]) {
      assert.equal((await sessions.POST(request({...session,[field]:invalid}))).status,400,field+' accepted '+JSON.stringify(invalid));
    }
  }
  assert.equal((await sessions.POST(request({...session,durationS:0,carbsG:0,rateGph:0}))).status,201);
  assert.equal((await sessions.POST(request({...session,targetGph:'60'}))).status,201);
});
