import { buildPlan } from './plan.js';
import { estimateEnergy } from './energy.js';
import { mealsOn } from './meals.js';
import { demoProfile, demoSessions, demoMeals } from './demo.js';
import { connectionView, liveState } from './live.js';
import { calendarDate } from './profile.js';

// The browser sends its own calendar date so "today" matches the user's
// day, not the server's UTC day. Accept it only when within a day of ours.
export function resolveToday(requested, now = Date.now()) {
  const server = new Date(now).toISOString().slice(0, 10);
  try {
    calendarDate(requested);
    if (Math.abs(Date.parse(requested) - Date.parse(server)) <= 86400000) return requested;
  } catch { /* fall through to the server's date */ }
  return server;
}

// Everything the home screen needs, from one place. `store` is injected so
// tests can run it without Redis.
export async function loadOverview(store, { demo, today, now = Math.floor(Date.now() / 1000) }) {
  const [savedProfile, decisions, savedMeals] = await Promise.all([
    store.getProfile(demo), store.listDecisions(demo), store.listMeals(demo),
  ]);
  let profile, sessions, days, meals, live = [], beats = [], fuelling = [];
  if (demo) {
    // Demo never reads real activity, live telemetry or heartbeats.
    profile = savedProfile ?? demoProfile(today);
    sessions = demoSessions(today);
    days = [];
    meals = [...savedMeals, ...demoMeals(today)];
  } else {
    profile = savedProfile;
    [sessions, days, live, beats, fuelling] = await Promise.all([
      store.listPaceSessions(), store.listDays(), store.listLive(now), store.listBeats(), store.listSessions(),
    ]);
    sessions = sessions.filter(session => session.mode === 'LIVE');
    meals = savedMeals;
  }
  const plan = buildPlan({ profile, sessions, days, decisions, today });
  const liveStreams = live.filter(stream => stream.mode === 'LIVE');
  // Calories the watch reported for today's fuelling sessions. Shown beside
  // the estimate, never added to it.
  const activityKcal = fuelling.filter(s => !s.demo && s.calories > 0 && new Date(s.at * 1000).toISOString().slice(0, 10) === today)
    .reduce((sum, s) => sum + s.calories, 0);
  // What was logged during today's workouts, from either watch app.
  const onToday = seconds => new Date(seconds * 1000).toISOString().slice(0, 10) === today;
  const logged = [...sessions.filter(s => onToday(s.endedAt)), ...fuelling.filter(s => !s.demo && onToday(s.at))];
  const workoutIntake = {
    fluidMl: logged.reduce((sum, s) => sum + (s.fluidMl ?? 0), 0),
    carbsG: logged.reduce((sum, s) => sum + (s.carbsG ?? 0), 0),
  };
  return {
    demo, today, now, profile, plan, workoutIntake,
    recent: sessions.slice(0, 14),
    energy: estimateEnergy(profile ?? {}),
    mealsToday: mealsOn(meals, today),
    activityKcalToday: activityKcal > 0 ? activityKcal : null,
    watch: demo ? null : {
      connection: connectionView(liveStreams, now),
      streams: liveStreams.map(stream => ({ ...stream, state: liveState(stream, now) })),
      beats,
    },
  };
}
