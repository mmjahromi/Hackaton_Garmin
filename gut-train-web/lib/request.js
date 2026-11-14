import * as store from './store.js';
import { loadOverview, resolveToday } from './overview.js';

// Shared by the stay-active routes: which data set, and which calendar day.
export function context(request) {
  const url = new URL(request.url);
  return { url, demo: url.searchParams.get('mode') === 'demo', today: resolveToday(url.searchParams.get('today')) };
}
export const overview = (demo, today) => loadOverview(store, { demo, today });
export async function body(request) {
  try { return await request.json(); } catch { throw new Error('Body must be JSON'); }
}
export const bad = error => Response.json({ error: error.message }, { status: 400 });
// Watch uploads honour the same optional shared key as the other ingest routes.
export function keyError(request) {
  const required = process.env.INGEST_KEY;
  return required && request.headers.get('x-api-key') !== required
    ? Response.json({ error: 'Invalid API key' }, { status: 401 }) : null;
}
