import { getProfile, setProfile } from "../../../lib/store";
import { normalizeProfile } from "../../../lib/profile";
import { demoProfile } from "../../../lib/demo";
import { context, body, bad } from "../../../lib/request";

export const dynamic = "force-dynamic";

export async function GET(request) {
  const { demo, today } = context(request);
  const saved = await getProfile(demo);
  return Response.json({ profile: saved ?? (demo ? demoProfile(today) : null) });
}

export async function PUT(request) {
  const { demo } = context(request);
  let profile;
  try { profile = normalizeProfile(await body(request), { demo }); } catch (error) { return bad(error); }
  // Keep the first-saved time across edits: missed days are counted from it.
  const existing = await getProfile(demo);
  profile.createdAt = existing?.createdAt ?? existing?.updatedAt ?? profile.updatedAt;
  await setProfile(profile, demo);
  return Response.json({ profile });
}
