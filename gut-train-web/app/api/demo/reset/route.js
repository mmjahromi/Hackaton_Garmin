import { resetDemo } from "../../../../lib/store";

export const dynamic = "force-dynamic";

// Clears only what was changed while exploring the demo. Real records are
// stored under different keys and are never touched.
export async function POST() {
  await resetDemo();
  return Response.json({ ok: true });
}
