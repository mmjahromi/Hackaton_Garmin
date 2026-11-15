import { WEEKDAYS, ACTIVITIES, object, integer, calendarDate } from './profile.js';
export const shiftDate = (date, offset) => new Date(Date.parse(date + 'T00:00:00Z') + offset * 86400000).toISOString().slice(0, 10);
const weekday = date => WEEKDAYS[(new Date(date + 'T00:00:00Z').getUTCDay() + 6) % 7];
export const planId = (date, demo = false) => `stay_active:${demo ? 'demo' : 'real'}:${date}`;
export function normalizeDecision(body, suggestion, today) {
  object(body);
  if (body.id !== suggestion.id || (suggestion.status === 'done' && body.action !== 'new')) throw new Error('Choose the current unfinished suggestion');
  if (!['accept', 'adjust', 'reschedule', 'easier', 'rest', 'new'].includes(body.action)) throw new Error('Invalid action');
  if (body.durationMin !== undefined) integer(body.durationMin, 10, 90, 'durationMin');
  if (body.activity !== undefined && !ACTIVITIES.includes(body.activity)) throw new Error('Invalid activity');
  if (body.toDate !== undefined) calendarDate(body.toDate);
  if (body.action === 'adjust' && body.durationMin === undefined && body.activity === undefined) throw new Error('Choose a duration or activity');
  if (!['adjust', 'new'].includes(body.action) && (body.durationMin !== undefined || body.activity !== undefined)) throw new Error('Duration and activity require adjust');
  if (body.action !== 'reschedule' && body.toDate !== undefined) throw new Error('A new date requires reschedule');
  if (body.action === 'reschedule' && (!body.toDate || body.toDate <= today || body.toDate > shiftDate(today, 14))) throw new Error('Reschedule within the next 14 days');
  if (body.action === 'new' && (suggestion.status !== 'done' || body.durationMin === undefined || body.activity === undefined)) throw new Error('Choose an activity and duration after completing the current plan');
  let next = { ...suggestion };
  if (body.action === 'new') {
    const sequence = Number(suggestion.id.match(/:extra:(\d+)$/)?.[1] ?? 0) + 1;
    next = { ...next, id: `${planId(today, suggestion.demo)}:extra:${sequence}`, date: today,
      kind: 'workout', activity: body.activity, durationMin: body.durationMin, status: 'adjusted',
      basis: ['An optional additional session you chose. Completed workouts remain in your history.'] };
  }
  if (body.action === 'accept') next.status = 'accepted';
  if (body.action === 'adjust') next = { ...next, kind: 'workout', activity: body.activity ?? next.activity ?? 'walk', durationMin: body.durationMin ?? Math.max(10, next.durationMin), status: 'adjusted' };
  if (body.action === 'easier') next = { ...next, kind: 'workout', activity: next.activity === 'run_walk' ? 'walk' : next.activity ?? 'walk', durationMin: Math.max(10, Math.round(next.durationMin * 0.75)), status: 'adjusted' };
  if (body.action === 'rest') next = { ...next, kind: 'rest', activity: null, durationMin: 0, status: 'rest_chosen' };
  if (body.action === 'reschedule') next = { ...next, date: body.toDate, status: 'rescheduled' };
  const reasons = { new: 'You chose an additional session. Rest is still an option.', accept: 'You accepted this plan.', adjust: 'You adjusted this plan to suit you.', easier: 'You chose an easier session.', rest: 'You chose rest today.', reschedule: `You moved this session to ${body.toDate}.` };
  next.reason = reasons[body.action];
  next.basis = [...next.basis, reasons[body.action]];
  return { id: body.id, action: body.action, date: today, ...(body.toDate ? { toDate: body.toDate } : {}), suggestion: next, demo: suggestion.demo };
}

// UTC calendar dates throughout: deterministic across browsers and servers.
// Recent means the last 14 calendar days. Feedback uses the watch enums:
// effort 0=easy,1=about right,2=too hard,3=skipped; energy 0=low;
// soreness 2=high. HR, HR coverage and nextGoalSec never drive progression.
export function buildPlan({ profile, sessions = [], days = [], decisions = [], today }) {
  calendarDate(today);
  const demo = profile?.demo === true;
  const sameMode = record => (record.demo === true || record.mode === 'DEMO') === demo;
  const start = shiftDate(today, -13);
  const recent = sessions.filter(s => sameMode(s) && s.sessionSec > 0 && s.effort !== 3)
    .map(s => ({ ...s, date: new Date(s.endedAt * 1000).toISOString().slice(0,10) }))
    .filter(s => s.date >= start && s.date <= today).sort((a,b) => b.endedAt - a.endedAt || b.sessionId - a.sessionId);
  const choices = decisions.filter(sameMode);
  const scheduled = date => choices.find(d => d.suggestion?.date === date && d.date !== date && d.action === 'reschedule');
  const choice = date => choices.find(d => d.date === date);
  const planned = date => {
    const own = choice(date);
    if (own?.action === 'rest' || (own?.action === 'reschedule' && own.toDate !== date)) return false;
    return Boolean(scheduled(date) || (own && own.suggestion?.kind === 'workout') || profile?.days.includes(weekday(date)));
  };
  const consistency = Array.from({length:14}, (_,i) => {
    const date = shiftDate(start,i), rows = recent.filter(s => s.date === date);
    return { date, planned: planned(date), done: rows.length > 0, durationMin: rows.length ? Math.round(rows.reduce((n,s) => n+s.sessionSec,0)/60) : null, effort: rows.length ? ({0:'easy',1:'about right',2:'too hard'})[rows[0].effort] ?? null : null, demo };
  });
  const monday = shiftDate(today, -(new Date(today+'T00:00:00Z').getUTCDay()+6)%7);
  const thisWeek = consistency.filter(d => d.date >= monday);
  // Only complete weeks entirely covered by this history can count as a streak.
  let streakWeeks = 0;
  for (let end = shiftDate(monday,-1); shiftDate(end,-6) >= start; end = shiftDate(end,-7)) {
    const week = consistency.filter(d => d.date >= shiftDate(end,-6) && d.date <= end && d.planned);
    if (!week.length || week.some(d => !d.done)) break;
    streakWeeks++;
  }
  const week = { plannedDays: Array.from({length:7},(_,i)=>shiftDate(monday,i)).filter(planned).length, doneDays: thisWeek.filter(d=>d.done).length, missedDays: thisWeek.filter(d=>d.planned&&!d.done&&d.date<today).length, streakWeeks, demo };
  let suggestion = { id: planId(today,demo), date: today, kind:'rest', activity:null, durationMin:0, effort:'easy', reason:'Choose your activity preferences to get a plan.', basis:['No profile yet'], status:'suggested', demo };
  if (!profile) return { today, suggestion, week, consistency, demo };
  const usual = profile.durationMin;
  suggestion = { ...suggestion, kind:'workout', activity:profile.activities[0], durationMin:usual, reason:'Repeat your usual easy session to build consistency.', basis:[`Preferred duration: ${usual} minutes`, 'No change needed'] };
  let misses = 0;
  // Do not invent missed sessions before the first available evidence/profile.
  // A planned day can only be missed once the person had a plan: days before
  // the preferences were first saved do not count against them.
  const since = profile.createdAt ?? profile.updatedAt;
  const enrolled = Number.isFinite(since) ? new Date(since * 1000).toISOString().slice(0, 10) : start;
  for (const day of consistency.filter(d=>d.date<today && d.planned && d.date>=enrolled).reverse()) {
    if (day.done) break;
    misses++;
  }
  const last = recent[0];
  const recovery = days.some(d=>sameMode(d)&&d.date===today&&d.recoveryDay);
  if (misses >= 2) {
    suggestion.durationMin = Math.max(10, Math.round(usual * 0.6));
    suggestion.reason = 'Restart with a shorter session after missing planned days.';
    suggestion.basis = [`${misses} missed planned days in a row`, `Usual duration: ${usual} minutes`, 'No catch-up needed'];
  } else if (last?.effort === 2 || last?.soreness === 2 || last?.energy === 0 || recovery) {
    suggestion.durationMin = Math.max(10,Math.round(usual*0.75));
    if (suggestion.activity === 'run_walk') suggestion.activity = 'walk';
    suggestion.reason = 'Try an easier session because your recent feedback calls for recovery.';
    suggestion.basis = [last?.effort===2&&'Last session felt too hard',last?.soreness===2&&'High soreness',last?.energy===0&&'Low energy',recovery&&'Recovery day'].filter(Boolean);
  } else if (recent.length >= 3 && recent.slice(0,3).every(s=>[0,1].includes(s.effort) && s.soreness !== 2 && s.energy !== 0)) {
    suggestion.durationMin = Math.min(90,usual+15,Math.round(usual*1.1/5)*5);
    suggestion.reason = suggestion.durationMin > usual ? 'You could try a little longer after three manageable sessions.' : 'Keep your usual duration after three manageable sessions.';
    suggestion.basis = ['Last three sessions felt easy or about right','No high soreness or low energy reported','Duration change is only an offer'];
  }
  if (!planned(today)) suggestion = { ...suggestion, kind:'rest', activity:'walk', durationMin:10, reason:'Rest today, with an optional short easy walk.', basis:['Today is not a planned workout day'] };
  const nextSessionSuggestion = {
    activity: suggestion.activity ?? 'walk',
    durationMin: Math.min(usual, suggestion.durationMin || 10),
    reason: suggestion.reason,
    basis: suggestion.basis,
  };
  if (suggestion.durationMin > usual) {
    nextSessionSuggestion.reason = 'Keep an additional session within your preferred duration. There is no need to add more today.';
  }
  if (last?.effort === 2 || last?.soreness === 2 || last?.energy === 0 || recovery) {
    nextSessionSuggestion.activity = nextSessionSuggestion.activity === 'run_walk' ? 'walk' : nextSessionSuggestion.activity;
    nextSessionSuggestion.durationMin = Math.min(nextSessionSuggestion.durationMin, Math.max(10, Math.round(usual * 0.75)));
    nextSessionSuggestion.reason = 'Recent feedback calls for recovery. If you choose another session, keep it easy; resting is also an option.';
  }
  const decision = choice(today) ?? scheduled(today);
  if (decision?.suggestion) suggestion = { ...decision.suggestion, demo };
  if (recent.some(s=>s.planId===suggestion.id) || decision?.action==='done') suggestion = { ...suggestion, status:'done', reason:'You completed this planned session.', basis:[...suggestion.basis,'Completed watch session'] };
  return { today, suggestion, week, consistency, demo, ...(suggestion.status === 'done' ? { nextSessionSuggestion } : {}) };
}
