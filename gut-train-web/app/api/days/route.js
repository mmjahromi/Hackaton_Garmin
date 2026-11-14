import { listDays, upsertDay } from "../../../lib/store";

export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json({ days: await listDays() });
}

export async function POST(request) {
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
  const date = typeof body.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(body.date)
    ? new Date(`${body.date}T00:00:00Z`) : null;
  if (!date || !Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== body.date) {
    return Response.json({ error: "Enter a real date in YYYY-MM-DD format" }, { status: 400 });
  }
  const day = { date: body.date };
  const ranges = { steps: 100000, activeMin: 1440, floors: 500, bodyBattery: 100,
    dailyTarget: 1440, weekTarget: 10080, nudges: 100, nudgesAnswered: 100 };
  const invalid = [];
  for (const [field, max] of Object.entries(ranges)) {
    const value = body[field];
    if (!(field === "bodyBattery" && value === null) &&
      (!Number.isInteger(value) || value < 0 || value > max)) invalid.push(field);
    day[field] = value;
  }
  for (const field of ["recoveryDay", "demo"]) {
    if (typeof body[field] !== "boolean") invalid.push(field);
    day[field] = body[field];
  }
  if (invalid.length) {
    return Response.json({ error: `Missing or invalid fields: ${invalid.join(", ")}` }, { status: 400 });
  }
  await upsertDay(day);
  return Response.json({ ok: true }, { status: 201 });
}
