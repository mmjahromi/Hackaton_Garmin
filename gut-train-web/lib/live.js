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
  for (const [key,max] of Object.entries({stress:100,stressAt:4102444800})) {
    const value=body[key] ?? null;
    if (value !== null && (!Number.isInteger(value) || value<0 || value>max)) throw new Error('Invalid '+key);
    result[key]=value;
  }
  if (result.stress !== null && result.stressAt === null) throw new Error('Missing stressAt');
  if (result.stressAt !== null && result.stressAt>result.sampledAt+60) throw new Error('Future stressAt');
  if (result.status !== 'active') {
    result.heartRate=null;
    result.stress=null;
    result.stressAt=null;
  }
  return result;
}
export function stressView(packet, now) {
  if (!packet || packet.stress == null || packet.stressAt == null || packet.status !== 'active') return null;
  const value=packet.stress;
  const ageSec=Math.max(0,now-packet.stressAt);
  const band=value<=25?'resting':value<=50?'low':value<=75?'medium':'high';
  return {value,band,ageSec,fresh:ageSec<=300};
}
export function connectionView(streams, now) {
  return Object.fromEntries(['pacepilot','guttrain'].map(app=>{
    const packet=streams.filter(s=>s.app===app && s.mode==='LIVE')
      .reduce((latest,s)=>!latest || s.receivedAt>latest.receivedAt ||
        (s.receivedAt===latest.receivedAt && (s.sessionId>latest.sessionId ||
          (s.sessionId===latest.sessionId && s.sequence>latest.sequence))) ? s : latest,null);
    const state=liveState(packet,now);
    const connected=state==='active' || state==='paused';
    // Use the watch's sample time: delayed delivery does not make a reading new.
    const age=packet?Math.max(0,Math.floor(now-packet.sampledAt)):0;
    const ago=age<60?`${age} seconds ago`:`${Math.floor(age/60)} min ago`;
    const detail=state==='active'?'Live now':state==='paused'?'Paused':
      state==='completed'?`Session finished ${ago}`:state==='stale'?`Last seen ${ago}`:'No session yet';
    return [app,{connected,label:connected?'Connected':'Not connected',detail}];
  }));
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
