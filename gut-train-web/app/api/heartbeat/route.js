import { listBeats, saveBeat } from "../../../lib/store";
import { normalizeBeat } from "../../../lib/meals";
import { body, bad, keyError } from "../../../lib/request";

export const dynamic = "force-dynamic";

// A check-in means only: this watch app reached the dashboard, through the
// phone, at this time. It is not live telemetry.
export async function GET() {
  return Response.json({ beats: await listBeats() });
}

export async function POST(request) {
  const denied = keyError(request);
  if (denied) return denied;
  let beat;
  try { beat = normalizeBeat(await body(request)); } catch (error) { return bad(error); }
  await saveBeat(beat);
  return Response.json({ ok: true }, { status: 201 });
}
