import { object, calendarDate } from './profile.js';

// User-entered intake. Never derived from the watch.
export function normalizeMeal(body, { demo = false, now = Math.floor(Date.now() / 1000) } = {}) {
  object(body);
  calendarDate(body.date);
  if (!Number.isInteger(body.kcal) || body.kcal < 1 || body.kcal > 5000) throw new Error('Enter calories as a whole number from 1 to 5000');
  let label = null;
  if (body.label != null) {
    if (typeof body.label !== 'string' || body.label.trim().length > 40) throw new Error('Keep the label to 40 characters');
    label = body.label.trim() || null;
  }
  let at = now;
  if (body.at != null) {
    if (!Number.isInteger(body.at) || body.at < 0 || body.at > now + 60) throw new Error('Invalid time');
    at = body.at;
  }
  return { id: `${at}-${Math.floor(Math.random() * 1e9).toString(36)}`, date: body.date, kcal: body.kcal, label, at, demo };
}

export function mealsOn(meals, date) {
  const rows = meals.filter(meal => meal.date === date);
  return { date, count: rows.length, kcal: rows.reduce((sum, meal) => sum + meal.kcal, 0), meals: rows };
}

export function normalizeBeat(body, now = Math.floor(Date.now() / 1000)) {
  object(body);
  if (body.schemaVersion !== 1 || !['pacepilot', 'guttrain'].includes(body.app)) throw new Error('Invalid heartbeat');
  if (!Number.isInteger(body.at) || body.at < 0 || body.at > now + 60) throw new Error('Invalid at');
  let batteryPct = null;
  if (body.batteryPct != null) {
    if (!Number.isInteger(body.batteryPct) || body.batteryPct < 0 || body.batteryPct > 100) throw new Error('Invalid batteryPct');
    batteryPct = body.batteryPct;
  }
  return { app: body.app, at: body.at, receivedAt: now, batteryPct };
}
