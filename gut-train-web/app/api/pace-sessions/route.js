import { listPaceSessions, upsertPaceSession } from "../../../lib/store";
import { normalizePaceSession } from "../../../lib/pace";

export const dynamic = "force-dynamic";
export async function GET() {
  return Response.json({ sessions: await listPaceSessions() });
}
export async function POST(request) {
  const requiredKey = process.env.INGEST_KEY;
  if (requiredKey && request.headers.get("x-api-key") !== requiredKey) {
    return Response.json({ error: "Invalid API key" }, { status: 401 });
  }
  let session;
  try {
    session = normalizePaceSession(await request.json());
  } catch (error) {
    return Response.json({ error: error.message }, { status: 400 });
  }
  await upsertPaceSession(session);
  return Response.json({ ok: true }, { status: 201 });
}
