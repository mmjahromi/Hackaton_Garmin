import { saveDecision } from "../../../../lib/store";
import { normalizeDecision } from "../../../../lib/plan";
import { context, overview, body, bad } from "../../../../lib/request";

export const dynamic = "force-dynamic";

// Accept, adjust, reschedule, make easier or rest. Nothing changes a plan
// except one of these explicit choices.
export async function POST(request) {
  const { demo, today } = context(request);
  const current = await overview(demo, today);
  if (!current.profile) return Response.json({ error: "Set your preferences first" }, { status: 409 });
  let decision;
  try { decision = normalizeDecision(await body(request), current.plan.suggestion, today); } catch (error) { return bad(error); }
  await saveDecision(decision, demo);
  return Response.json((await overview(demo, today)).plan);
}
