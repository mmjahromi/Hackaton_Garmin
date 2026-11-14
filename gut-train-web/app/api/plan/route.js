import { context, overview } from "../../../lib/request";

export const dynamic = "force-dynamic";

export async function GET(request) {
  const { demo, today } = context(request);
  return Response.json((await overview(demo, today)).plan);
}
