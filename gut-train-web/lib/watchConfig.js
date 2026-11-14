// What the watch may fetch. Only with the user's explicit "Send plan to
// watch" consent, and only the real plan: a demo plan never reaches a watch.
export function watchConfig(profile, plan, now = Math.floor(Date.now() / 1000)) {
  if (!profile || profile.demo === true || profile.shareToWatch !== true || !plan?.suggestion) {
    return { schemaVersion: 1, available: false };
  }
  const s = plan.suggestion;
  const reason = s.reason.length > 60 ? s.reason.slice(0, 59).trimEnd() + '…' : s.reason;
  return {
    schemaVersion: 1, available: true, goal: 'stay_active',
    suggestion: { id: s.id, kind: s.kind, activity: s.activity, durationMin: s.durationMin, reason, status: s.status },
    updatedAt: now,
  };
}

// The demo plan, clearly marked. It lets someone try the watch flow before
// saving preferences. A watch must label it as a demo and never report a
// session against it.
export function demoWatchConfig(plan, now = Math.floor(Date.now() / 1000)) {
  const s = plan.suggestion;
  const reason = s.reason.length > 60 ? s.reason.slice(0, 59).trimEnd() + '…' : s.reason;
  return {
    schemaVersion: 1, available: true, demo: true, goal: 'stay_active',
    suggestion: { id: s.id, kind: s.kind, activity: s.activity, durationMin: s.durationMin, reason, status: s.status },
    updatedAt: now,
  };
}
