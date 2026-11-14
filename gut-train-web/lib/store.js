// Session storage.
//
// With UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN set (a Redis
// database added from the Vercel Marketplace), sessions are kept in Redis.
// Without them, sessions live in memory: fine for local development, but on
// Vercel they vanish whenever the function restarts.

const KEY = "gut-train:sessions";
const MAX_SESSIONS = 200;

const redisUrl = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const redisToken = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

export const isPersistent = Boolean(redisUrl && redisToken);

async function redis(command) {
  const response = await fetch(redisUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${redisToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(command),
    cache: "no-store",
  });
  if (!response.ok) {
    throw new Error(`Redis request failed with status ${response.status}`);
  }
  const data = await response.json();
  if (data.error) throw new Error("Redis command failed");
  return data.result;
}

function memory() {
  if (!globalThis.__gutTrainSessions) {
    globalThis.__gutTrainSessions = [];
  }
  return globalThis.__gutTrainSessions;
}

export async function addSession(session) {
  if (isPersistent) {
    await redis(["LPUSH", KEY, JSON.stringify(session)]);
    await redis(["LTRIM", KEY, "0", String(MAX_SESSIONS - 1)]);
    return;
  }
  const sessions = memory();
  sessions.unshift(session);
  sessions.length = Math.min(sessions.length, MAX_SESSIONS);
}

// Newest first.
export async function listSessions() {
  if (isPersistent) {
    const rows = await redis(["LRANGE", KEY, "0", String(MAX_SESSIONS - 1)]);
    return rows.map((row) => JSON.parse(row));
  }
  return [...memory()];
}

const GOAL_KEY = "gut-train:goal";

export async function getGoal() {
  if (isPersistent) {
    const value = await redis(["GET", GOAL_KEY]);
    return value == null ? null : JSON.parse(value);
  }
  return globalThis.__gutTrainGoal ? JSON.parse(globalThis.__gutTrainGoal) : null;
}

export async function setGoal(goal) {
  const value = JSON.stringify(goal);
  if (isPersistent) {
    await redis(["SET", GOAL_KEY, value]);
    return;
  }
  globalThis.__gutTrainGoal = value;
}

const DAYS_KEY = "gut-train:days";
const MAX_DAYS = 60;

export async function upsertDay(day) {
  const value = JSON.stringify(day);
  if (isPersistent) {
    await redis(["HSET", DAYS_KEY, day.date, value]);
    const dates = await redis(["HKEYS", DAYS_KEY]);
    const expired = dates.sort().reverse().slice(MAX_DAYS);
    if (expired.length) await redis(["HDEL", DAYS_KEY, ...expired]);
    return;
  }
  const days = globalThis.__gutTrainDays ??= new Map();
  days.set(day.date, value);
  for (const date of [...days.keys()].sort().reverse().slice(MAX_DAYS)) days.delete(date);
}

// Dates are ISO calendar dates, so lexical order is chronological order.
export async function listDays() {
  const values = isPersistent
    ? await redis(["HVALS", DAYS_KEY])
    : [...(globalThis.__gutTrainDays ?? new Map()).values()];
  return values.map((value) => JSON.parse(value)).sort((a, b) => b.date.localeCompare(a.date)).slice(0, MAX_DAYS);
}

// Separate keys preserve each app's identity. Session IDs make retries idempotent.
const PACE_KEY = "pacepilot:sessions:v1";
export async function upsertPaceSession(session) {
  const key = session.mode + ":" + session.sessionId;
  if (isPersistent) {
    await redis(["HSET", PACE_KEY, key, JSON.stringify(session)]);
    const keys = await redis(["HKEYS", PACE_KEY]);
    const expired = keys.sort((a, b) => Number(b.split(":").at(-1)) - Number(a.split(":").at(-1))).slice(200);
    if (expired.length) await redis(["HDEL", PACE_KEY, ...expired]);
    return;
  }
  const records = globalThis.__pacePilotSessions ??= new Map();
  records.set(key, JSON.stringify(session));
  const expired = [...records.keys()].sort((a, b) => Number(b.split(":").at(-1)) - Number(a.split(":").at(-1))).slice(200);
  for (const id of expired) records.delete(id);
}
export async function listPaceSessions() {
  const rows = isPersistent
    ? await redis(["HVALS", PACE_KEY])
    : [...(globalThis.__pacePilotSessions ?? new Map()).values()];
  return rows.map(row => JSON.parse(row)).sort((a, b) => b.sessionId - a.sessionId).slice(0, 200);
}

// One most-recent session per app/mode, isolated from completed summaries.
// Redis Lua keeps ordering checks and bounded history atomic across functions.
const LIVE_KEY = 'garmin:live:v1';
const LIVE_SCRIPT = `
local raw=redis.call('HGET',KEYS[1],ARGV[1])
local incoming=cjson.decode(ARGV[2])
local history={}
if raw then
 local old=cjson.decode(raw)
 if old.sessionId>incoming.sessionId then return 0 end
 if old.sessionId==incoming.sessionId then
  if old.sequence>=incoming.sequence or old.status=='completed' then return 0 end
  history=old.samples
 end
end
local point=cjson.decode(ARGV[2])
table.insert(history,point)
while #history>120 do table.remove(history,1) end
incoming.samples=history
redis.call('HSET',KEYS[1],ARGV[1],cjson.encode(incoming))
redis.call('EXPIRE',KEYS[1],86400)
return 1`;
export async function upsertLive(packet, now = Math.floor(Date.now()/1000)) {
  const value={...packet,receivedAt:now};
  const key=packet.app+':'+packet.mode;
  if(isPersistent) return Boolean(await redis(['EVAL',LIVE_SCRIPT,'1',LIVE_KEY,key,JSON.stringify(value)]));
  const records=globalThis.__garminLive ??= new Map();
  const old=records.get(key);
  if(old && (old.sessionId>value.sessionId || (old.sessionId===value.sessionId && (old.sequence>=value.sequence || old.status==='completed')))) return false;
  const samples=old?.sessionId===value.sessionId ? old.samples : [];
  records.set(key,{...value,samples:[...samples,value].slice(-120)});
  return true;
}
export async function listLive(now = Math.floor(Date.now()/1000)) {
  const rows=isPersistent ? (await redis(['HVALS',LIVE_KEY])).map(JSON.parse) : [...(globalThis.__garminLive ?? new Map()).values()];
  return rows.filter(row=>now-row.receivedAt<86400).sort((a,b)=>b.receivedAt-a.receivedAt);
}

// ---- Stay-active data: profile, plan decisions, meals, heartbeat ----------
// Real and demo records live under different keys and never mix. Demo keys
// are the only ones resetDemo() touches.
async function kvGet(key) {
  const raw = isPersistent ? await redis(["GET", key]) : (globalThis.__gutTrainKv ??= new Map()).get(key) ?? null;
  return raw == null ? null : JSON.parse(raw);
}
async function kvSet(key, value) {
  const raw = JSON.stringify(value);
  if (isPersistent) { await redis(["SET", key, raw]); return; }
  (globalThis.__gutTrainKv ??= new Map()).set(key, raw);
}
async function kvDel(key) {
  if (isPersistent) { await redis(["DEL", key]); return; }
  (globalThis.__gutTrainKv ??= new Map()).delete(key);
}
const space = (demo, name) => `gut-train:${demo ? "demo:" : ""}${name}`;

export const getProfile = (demo = false) => kvGet(space(demo, "profile"));
export const setProfile = (profile, demo = false) => kvSet(space(demo, "profile"), profile);

export async function listDecisions(demo = false) {
  return (await kvGet(space(demo, "decisions"))) ?? [];
}
// One decision per calendar day; a newer choice for the same day replaces it.
export async function saveDecision(decision, demo = false) {
  const rows = (await listDecisions(demo)).filter(row => row.date !== decision.date);
  rows.unshift(decision);
  await kvSet(space(demo, "decisions"), rows.slice(0, 60));
}

export async function listMeals(demo = false) {
  return (await kvGet(space(demo, "meals"))) ?? [];
}
export async function addMeal(meal, demo = false) {
  const rows = await listMeals(demo);
  rows.unshift(meal);
  await kvSet(space(demo, "meals"), rows.slice(0, 300));
}
export async function deleteMeal(id, demo = false) {
  const rows = await listMeals(demo);
  const kept = rows.filter(row => row.id !== id);
  if (kept.length !== rows.length) await kvSet(space(demo, "meals"), kept);
  return kept.length !== rows.length;
}

// Newest check-in per watch app. Real mode only: a demo never has a watch.
export async function listBeats() {
  return Object.values((await kvGet("gut-train:heartbeat")) ?? {});
}
export async function saveBeat(beat) {
  const beats = (await kvGet("gut-train:heartbeat")) ?? {};
  beats[beat.app] = beat;
  await kvSet("gut-train:heartbeat", beats);
}

export async function resetDemo() {
  for (const name of ["profile", "decisions", "meals"]) await kvDel(space(true, name));
}
