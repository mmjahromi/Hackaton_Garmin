import { liveState } from './live.js';
export function liveInsights(session, now, offline=false) {
 const state=offline?'stale':liveState(session,now);
 const progress=session.goalSec>0?Math.min(100,Math.max(0,Math.round(session.elapsedSec/session.goalSec*100))):null;
 const remaining=session.goalSec>0?Math.max(0,session.goalSec-session.elapsedSec):null;
 if(state!=='active')return {moving:false,label:state==='completed'?'Session complete':state==='paused'?'Workout paused':'Waiting for fresh data',progress,remaining,notes:[state==='stale'?'Live guidance is paused until fresh readings arrive.':'Your last recorded progress is shown.']};
 const moving=Number.isFinite(session.speedMps)&&session.speedMps>0.3;
 const notes=[];
 if(progress!==null)notes.push(`${progress}% of your session goal recorded. Walking counts toward this goal.`);
 if(session.speedMps==null)notes.push('Movement is unconfirmed. Check GPS reception; the timer alone does not prove movement.');
 else if(!moving)notes.push('Little movement detected. Pause the workout if you are taking a break.');
 if(session.heartRate==null)notes.push('Heart rate is unavailable. Check watch fit; no effort assessment is being made.');
 const recent=(session.samples??[]).filter(p=>p.status==='active'&&p.heartRate!=null&&now-p.sampledAt<=60&&p.sampledAt<=now);
 if(recent.length>=4 && recent.at(-1).sampledAt-recent[0].sampledAt>=15){
  const delta=Math.round(recent.at(-1).heartRate-recent[0].heartRate);
  notes.push(`Heart rate ${Math.abs(delta)<5?'is roughly steady':delta>0?`rose ${delta} bpm`:`fell ${-delta} bpm`} across the recent samples. This alone does not determine whether to change effort.`);
 }
 return {moving,label:moving?'Movement detected':'Movement unconfirmed',progress,remaining,notes};
}
