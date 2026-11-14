import { getGoal, setGoal } from "../../../lib/store";

export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json({ goal: await getGoal() });
}

export async function PUT(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Body must be JSON" }, { status: 400 });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return Response.json({ error: "Body must be a JSON object" }, { status: 400 });
  }
  const { event, raceDate, targetGph } = body;
  if (!["sprint", "olympic", "half", "full"].includes(event)) {
    return Response.json({ error: "Choose a valid event" }, { status: 400 });
  }
  const date = typeof raceDate === "string" && /^\d{4}-\d{2}-\d{2}$/.test(raceDate)
    ? new Date(`${raceDate}T00:00:00Z`) : null;
  if (!date || !Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== raceDate) {
    return Response.json({ error: "Enter a real race date in YYYY-MM-DD format" }, { status: 400 });
  }
  if (!Number.isInteger(targetGph) || targetGph < 30 || targetGph > 120) {
    return Response.json({ error: "Target must be a whole number from 30 to 120 g/h" }, { status: 400 });
  }
  const goal = { event, raceDate, targetGph };
  try {
    await setGoal(goal);
    return Response.json({ goal });
  } catch {
    return Response.json({ error: "Could not save your goal. Try again." }, { status: 500 });
  }
}
