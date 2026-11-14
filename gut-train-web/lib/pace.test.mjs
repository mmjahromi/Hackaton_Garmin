import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const moduleUrl = source => "data:text/javascript;base64," + Buffer.from(source).toString("base64");
const paceUrl = moduleUrl(await readFile(new URL("./pace.js", import.meta.url), "utf8"));
const { normalizePaceSession, paceOverview } = await import(paceUrl);
const source = (await readFile(new URL("./store.js", import.meta.url), "utf8"))
  .replace(/const redisUrl = .*;/, "const redisUrl = null;")
  .replace(/const redisToken = .*;/, "const redisToken = null;");
const storeUrl = moduleUrl(source);
const store = await import(storeUrl);
const apiSource = (await readFile(new URL("../app/api/pace-sessions/route.js", import.meta.url), "utf8"))
  .replace('"../../../lib/store"', JSON.stringify(storeUrl))
  .replace('"../../../lib/pace"', JSON.stringify(paceUrl));
const api = await import(moduleUrl(apiSource));
const session = {
  schemaVersion: 1, mode: "LIVE", sessionId: 100, goalSec: 1200,
  sessionSec: 1200, movingSec: 1000, unknownMotionSec: 100,
  hrValidSec: 1100, walkPromptCount: 2, endedAt: 1200, goalMet: true,
  energy: 1, soreness: 0, effort: 1, routine: 2, nextGoalSec: 1200,
};
const request = body => new Request("http://localhost/api/pace-sessions", {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
});

test("pace summaries round trip and ignore unrecognized fields", async () => {
  const response = await api.POST(request({ ...session, rawRoute: "ignored" }));
  assert.equal(response.status, 201);
  const saved = (await (await api.GET()).json()).sessions[0];
  assert.deepEqual(saved, session);
});
test("pace summaries preserve missing check-ins in older payloads", () => {
  const old = { ...session };
  for (const key of ["energy", "soreness", "effort", "routine", "nextGoalSec"]) delete old[key];
  const result = normalizePaceSession(old);
  assert.equal(result.effort, null);
  assert.equal(result.nextGoalSec, null);
});
test("pace validation rejects malformed schemas and invalid totals", async () => {
  const bad = [null, [], {}, { ...session, schemaVersion: 2 }, { ...session, mode: "bad" },
    { ...session, sessionSec: -1 }, { ...session, sessionId: 0.5 },
    { ...session, movingSec: 1190 }, { ...session, hrValidSec: 1201 },
    { ...session, sessionSec: 1000 }, { ...session, goalMet: "true" },
    { ...session, effort: 5 }, { ...session, soreness: -1 }, { ...session, nextGoalSec: 10 }];
  for (const value of bad) assert.equal((await api.POST(request(value))).status, 400);
});
test("pace retries replace the same session without duplication", async () => {
  await api.POST(request({ ...session, effort: 2, nextGoalSec: 900 }));
  const rows = await store.listPaceSessions();
  assert.equal(rows.filter(row => row.sessionId === 100 && row.mode === "LIVE").length, 1);
  assert.equal(rows[0].effort, 2);
});
test("demo sessions cannot replace a same-ID live summary or inflate live totals", async () => {
  await api.POST(request({ ...session, mode: "DEMO" }));
  const rows = await store.listPaceSessions();
  assert.equal(rows.length, 2);
  assert.equal(paceOverview(rows).sessions, 1);
  assert.equal(paceOverview(rows).minutes, 20);
});
test("pace storage retains at most 200 records and orders newest first", async () => {
  for (let id = 101; id <= 305; id++) await store.upsertPaceSession({ ...session, sessionId: id });
  const rows = await store.listPaceSessions();
  assert.equal(rows.length, 200);
  assert.equal(rows[0].sessionId, 305);
  assert.equal(rows.at(-1).sessionId, 106);
});
test("pace ingestion respects configured API key", async () => {
  const previous = process.env.INGEST_KEY;
  process.env.INGEST_KEY = "test-only";
  try { assert.equal((await api.POST(request(session))).status, 401); }
  finally {
    if (previous === undefined) delete process.env.INGEST_KEY;
    else process.env.INGEST_KEY = previous;
  }
});
test("pace rejects malformed JSON with 400", async () => {
  const req = new Request("http://localhost/api/pace-sessions", { method: "POST", body: "{" });
  assert.equal((await api.POST(req)).status, 400);
});
