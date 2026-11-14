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
  return (await response.json()).result;
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
