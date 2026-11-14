import { watchConfig } from "../../../lib/watchConfig";
import { context, overview } from "../../../lib/request";

export const dynamic = "force-dynamic";

// Fetched by the watch only when the user chooses "Get today's plan".
export async function GET(request) {
  const { today } = context(request);
  const current = await overview(false, today);
  return Response.json(watchConfig(current.profile, current.plan));
}
