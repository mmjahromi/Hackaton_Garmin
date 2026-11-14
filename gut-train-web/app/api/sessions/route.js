import { addSession, listSessions } from "../../../lib/store";

export const dynamic = "force-dynamic";

// Read a whole number from the watch's payload, rejecting anything outside
// a sane range so one bad request can't corrupt the dashboard.
function wholeNumber(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max) {
    return null;
  }
  return Math.round(number);
}

// Optional readings must not turn null, blanks or booleans into zero.
function optionalWholeNumber(value, max) {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !value.trim()) return null;
  return wholeNumber(value, 0, max);
}

function optionalSignedWholeNumber(value, min, max) {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !value.trim()) return null;
  return wholeNumber(value, min, max);
}

export async function GET() {
  return Response.json({ sessions: await listSessions() });
}

export async function POST(request) {
  // If INGEST_KEY is set, the watch must send the same value in x-api-key.
  const requiredKey = process.env.INGEST_KEY;
  if (requiredKey && request.headers.get("x-api-key") !== requiredKey) {
    return Response.json({ error: "Invalid API key" }, { status: 401 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Body must be JSON" }, { status: 400 });
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return Response.json({ error: "Body must be a JSON object" }, { status: 400 });
  }

  const session = {
    at: wholeNumber(body.at, 0, 4102444800) ?? Math.floor(Date.now() / 1000),
    durationS: wholeNumber(body.durationS, 0, 24 * 3600),
    carbsG: wholeNumber(body.carbsG, 0, 5000),
    fluidMl: wholeNumber(body.fluidMl, 0, 30000),
    targetGph: wholeNumber(body.targetGph, 0, 200),
    rateGph: wholeNumber(body.rateGph, 0, 500),
    gutRating: wholeNumber(body.gutRating, 1, 5),
    nextTargetGph: wholeNumber(body.nextTargetGph, 0, 200),
    avgHr: wholeNumber(body.avgHr, 0, 250),
    calories: optionalWholeNumber(body.calories, 20000),
    maxHr: optionalWholeNumber(body.maxHr, 250),
    userMaxHr: optionalWholeNumber(body.userMaxHr, 250),
    gutEvents: optionalWholeNumber(body.gutEvents, 200),
    firstGutEventS: optionalWholeNumber(body.firstGutEventS, 86400),
    distanceM: optionalWholeNumber(body.distanceM, 500000),
    ascentM: optionalWholeNumber(body.ascentM, 20000),
    avgTempC: optionalSignedWholeNumber(body.avgTempC, -40, 60),
    maxTempC: optionalSignedWholeNumber(body.maxTempC, -40, 60),
    stops: optionalWholeNumber(body.stops, 500),
    stoppedS: optionalWholeNumber(body.stoppedS, 86400),
    hardFeeds: optionalWholeNumber(body.hardFeeds, 200),
    avgCadence: optionalWholeNumber(body.avgCadence, 250),
    hotDrinkPrompts: optionalWholeNumber(body.hotDrinkPrompts, 500),
    demo: body.demo === true,
    foodType: ["gel", "chews", "drink", "food"].includes(body.foodType) ? body.foodType : null,
    targetConfirmed: body.targetConfirmed === true,
    portionG: optionalWholeNumber(body.portionG, 200),
    drinkIntervalS: optionalWholeNumber(body.drinkIntervalS, 7200),
    fuelLog: Array.isArray(body.fuelLog) ? body.fuelLog.slice(0, 32).filter(entry =>
      entry && Number.isInteger(entry.atS) && entry.atS >= 0 && entry.atS <= 86400 &&
      Number.isInteger(entry.carbsG) && entry.carbsG > 0 && entry.carbsG <= 200 &&
      ["gel", "chews", "drink", "food"].includes(entry.kind)
    ).map(({ atS, carbsG, kind }) => ({ atS, carbsG, kind })) : [],
  };

  const missing = ["durationS", "carbsG", "targetGph", "rateGph", "gutRating", "nextTargetGph"]
    .filter((field) => session[field] === null);
  if (missing.length > 0) {
    return Response.json(
      { error: `Missing or invalid fields: ${missing.join(", ")}` },
      { status: 400 },
    );
  }

  await addSession(session);
  return Response.json({ ok: true }, { status: 201 });
}
