import { saveBeat } from "../../../lib/store";
import { watchConfig, demoWatchConfig } from "../../../lib/watchConfig";
import { context, overview } from "../../../lib/request";

export const dynamic = "force-dynamic";

// Fetched by a watch app when it opens, and when the user chooses "Get
// today's plan".
//   ?app=pacepilot|guttrain  records a check-in: "this app reached the
//                            dashboard now". No health data is involved.
//   ?mode=demo               returns the labelled demo plan, for trying the
//                            flow without a saved profile.
export async function GET(request) {
  const { url, demo, today } = context(request);
  const app = url.searchParams.get("app");
  if (["pacepilot", "guttrain"].includes(app)) {
    const now = Math.floor(Date.now() / 1000);
    await saveBeat({ app, at: now, receivedAt: now, batteryPct: null });
  }
  const current = await overview(demo, today);
  return Response.json(demo ? demoWatchConfig(current.plan) : watchConfig(current.profile, current.plan));
}
