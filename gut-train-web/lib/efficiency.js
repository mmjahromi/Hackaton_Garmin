// Fitness trend: how many heartbeats a kilometre costs at the person's usual
// pace. Fewer beats for the same pace over several weeks suggests the heart
// is working less for the same effort.
//
//   beats per km = average heart rate (beats/min) / speed (km/min)
//
// It is only meaningful as a trend across similar sessions. Heat, hills,
// sleep, caffeine and illness all move heart rate, so one session says
// little, and sessions at a clearly different pace are left out because
// beats per km falls as pace rises regardless of fitness.

export const MIN_SECONDS = 300;      // at least 5 minutes of usable readings
export const PACE_BAND = 0.15;       // within 15% of the usual pace
export const MIN_SESSIONS = 4;       // fewer than this is not a trend
export const STEADY_PERCENT = 3;     // smaller changes are treated as no change

export function beatsPerKm(avgHr, avgSpeedMps) {
  return Math.round(avgHr / (avgSpeedMps * 0.06));
}

const median = values => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
};
const mean = values => values.reduce((sum, value) => sum + value, 0) / values.length;

export function buildEfficiency(sessions) {
  const usable = sessions
    .filter(s => Number.isFinite(s.avgHr) && Number.isFinite(s.avgSpeedMps) && s.avgSpeedMps > 0 && (s.effSec ?? 0) >= MIN_SECONDS)
    .map(s => ({
      date: new Date(s.endedAt * 1000).toISOString().slice(0, 10), endedAt: s.endedAt,
      avgHr: s.avgHr, speedKmh: Math.round(s.avgSpeedMps * 36) / 10, avgSpeedMps: s.avgSpeedMps,
      minutes: Math.round(s.effSec / 60), beatsPerKm: beatsPerKm(s.avgHr, s.avgSpeedMps),
      demo: s.demo === true || s.mode === 'DEMO',
    }))
    .sort((a, b) => a.endedAt - b.endedAt);
  const withoutReadings = sessions.length - usable.length;
  if (!usable.length) {
    return { available: false, points: [], leftOut: 0, withoutReadings,
      reason: 'No session yet has at least five minutes of heart rate and GPS speed together.' };
  }
  const usualSpeed = median(usable.map(p => p.avgSpeedMps));
  const points = usable.filter(p => Math.abs(p.avgSpeedMps - usualSpeed) <= usualSpeed * PACE_BAND);
  const leftOut = usable.length - points.length;
  const usualPaceKmh = Math.round(usualSpeed * 36) / 10;
  if (points.length < MIN_SESSIONS) {
    return { available: false, points, leftOut, withoutReadings, usualPaceKmh,
      reason: `A trend needs ${MIN_SESSIONS} sessions at a similar pace. You have ${points.length} so far.` };
  }
  // Compare the earlier half with the later half, so one odd day cannot swing it.
  const half = Math.floor(points.length / 2);
  const before = mean(points.slice(0, half).map(p => p.beatsPerKm));
  const after = mean(points.slice(points.length - half).map(p => p.beatsPerKm));
  const changePct = Math.round(((after - before) / before) * 1000) / 10;
  const direction = changePct <= -STEADY_PERCENT ? 'improving' : changePct >= STEADY_PERCENT ? 'rising' : 'steady';
  const summary = direction === 'improving'
    ? `The same pace now costs about ${Math.abs(changePct)}% fewer heartbeats than in your earlier sessions.`
    : direction === 'rising'
      ? `The same pace is costing about ${changePct}% more heartbeats lately. Heat, hills, poor sleep or tiredness often explain this.`
      : 'Your heartbeats per km are holding steady.';
  return { available: true, points, leftOut, withoutReadings, usualPaceKmh,
    beforeBeatsPerKm: Math.round(before), afterBeatsPerKm: Math.round(after), changePct, direction, summary };
}
