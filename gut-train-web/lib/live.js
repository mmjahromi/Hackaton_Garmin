export const LIVE_STALE_SECONDS = 20;
export function normalizeLive(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body) || body.schemaVersion !== 1 ||
      !['pacepilot', 'guttrain'].includes(body.app) || !['LIVE', 'DEMO'].includes(body.mode) ||
      !['active', 'paused', 'completed'].includes(body.status)) throw new Error('Invalid live packet');
  const result = { schemaVersion: 1, app: body.app, mode: body.mode, status: body.status };
  for (const [key, max] of Object.entries({sessionId:4102444800, sequence:1000000, sampledAt:4102444800, elapsedSec:86400})) {
    if (!Number.isInteger(body[key]) || body[key] < 0 || body[key] > max) throw new Error('Invalid '+key);
    result[key] = body[key];
  }
  const optional = {heartRate:[30,250],goalSec:[60,86400],movingSec:[0,86400],speedMps:[0,100],distanceM:[0,500000],carbsG:[0,5000],fluidMl:[0,30000]};
  for (const [key,[min,max]] of Object.entries(optional)) {
    const value=body[key] ?? null;
    if (value !== null && (typeof value !== 'number' || !Number.isFinite(value) || value<min || value>max)) throw new Error('Invalid '+key);
    result[key]=value;
  }
  if (result.movingSec !== null && result.movingSec>result.elapsedSec) throw new Error('Invalid moving time');
  if (result.status !== 'active') result.heartRate=null;
  return result;
}
export function liveState(packet, now) {
  if (!packet) return 'waiting';
  if (packet.status === 'completed') return 'completed';
  if (now-packet.receivedAt>LIVE_STALE_SECONDS || now-packet.sampledAt>LIVE_STALE_SECONDS || packet.sampledAt-now>60) return 'stale';
  return packet.status;
}
// A chart gap remains a gap, rather than interpolating sensor loss.
export function hrSegments(samples) {
  const segments=[]; let current=[];
  for (const sample of samples) {
    if (sample.heartRate == null || sample.status !== 'active') {
      if(current.length) segments.push(current); current=[];
    } else {
      if(current.length && sample.sampledAt-current.at(-1).sampledAt>20) {segments.push(current);current=[];}
      current.push(sample);
    }
  }
  if(current.length) segments.push(current);
  return segments;
}
