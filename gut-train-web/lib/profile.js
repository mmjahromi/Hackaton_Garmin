export const ACTIVITIES = ['walk', 'run_walk', 'cycle'];
export const WEEKDAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
export function object(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Body must be a JSON object');
}
export function integer(value, min, max, name) {
  if (!Number.isInteger(value) || value < min || value > max) throw new Error(`Invalid ${name}`);
  return value;
}
export function calendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new Error('Use a date in YYYY-MM-DD format');
  const time = Date.parse(value + 'T00:00:00Z');
  if (!Number.isFinite(time) || new Date(time).toISOString().slice(0, 10) !== value) throw new Error('Enter a real date');
  return value;
}
export function normalizeProfile(body, { demo = false, now = Math.floor(Date.now() / 1000) } = {}) {
  object(body);
  if (body.goal !== 'stay_active') throw new Error('Only stay_active is supported');
  const result = { goal: 'stay_active' };
  for (const [key, allowed, max] of [['activities', ACTIVITIES, 3], ['days', WEEKDAYS, 7]]) {
    const values = body[key];
    if (!Array.isArray(values) || !values.length || values.length > max || new Set(values).size !== values.length || values.some(v => !allowed.includes(v))) throw new Error(`Invalid ${key}`);
    result[key] = [...values];
  }
  result.durationMin = integer(body.durationMin, 10, 90, 'durationMin');
  if (!['new', 'returning', 'regular'].includes(body.experience)) throw new Error('Invalid experience');
  result.experience = body.experience;
  for (const [key, min, max] of [['ageYears', 13, 100], ['heightCm', 100, 230], ['weightKg', 30, 250]]) {
    result[key] = body[key] == null ? null : integer(body[key], min, max, key);
  }
  for (const [key, values] of [['sexForEstimate', ['female', 'male']], ['dayActivity', ['mostly_sitting', 'on_feet', 'physical_job']]]) {
    if (body[key] != null && !values.includes(body[key])) throw new Error(`Invalid ${key}`);
    result[key] = body[key] ?? null;
  }
  if (typeof body.shareToWatch !== 'boolean') throw new Error('Choose whether to share the plan to your watch');
  return { ...result, shareToWatch: body.shareToWatch, updatedAt: now, demo };
}
