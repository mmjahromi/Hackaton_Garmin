'use client';
import LiveRunner from './LiveRunner';
import {useEffect,useState} from 'react';
import {liveState,hrSegments,stressView,connectionView} from '../lib/live';
const clock=s=>Math.floor(s/60)+':'+String(Math.floor(s%60)).padStart(2,'0');
const ageLabel=s=>s<60?`${Math.floor(s)} seconds ago`:`${Math.floor(s/60)} min ago`;
function HeartRateChart({samples}) {
 const first=samples[0]?.sampledAt ?? 0;
 const span=Math.max(60,(samples.at(-1)?.sampledAt ?? first)-first);
 return <svg viewBox="0 0 600 150" width="100%" role="img" aria-label="Recent heart rate, 30 to 250 beats per minute. Gaps indicate missing readings.">
   {[50,100,150,200].map(hr=><g key={hr}><line x1="35" x2="590" y1={140-(hr-30)/220*130} y2={140-(hr-30)/220*130} stroke="currentColor" opacity=".12"/><text x="0" y={144-(hr-30)/220*130} fill="currentColor" fontSize="11">{hr}</text></g>)}
   {hrSegments(samples).map((segment,i)=><polyline key={i} fill="none" stroke="currentColor" strokeWidth="2" points={segment.map(s=>(35+(s.sampledAt-first)/span*555)+','+(140-(s.heartRate-30)/220*130)).join(' ')}/>)}
 </svg>;
}
export default function LiveActivity() {
 const [streams,setStreams]=useState([]),[error,setError]=useState(false),[now,setNow]=useState(0),[persistent,setPersistent]=useState(true);
 useEffect(()=>{
  let cancelled=false,timer,offset=0;
  const tick=setInterval(()=>setNow(Date.now()/1000+offset),1000);
  async function poll(){
   try {
    const r=await fetch('/api/live',{cache:'no-store',signal:AbortSignal.timeout(8000)});
    if(!r.ok) throw new Error();
    const data=await r.json();
    if(!cancelled){offset=data.serverNow-Date.now()/1000;setNow(data.serverNow);setStreams(data.streams);setPersistent(data.persistent);setError(false);}
   }catch{if(!cancelled)setError(true);}
   if(!cancelled)timer=setTimeout(poll,2000);
  }
  poll();return()=>{cancelled=true;clearTimeout(timer);clearInterval(tick);};
 },[]);
 const connections=connectionView(streams,now);
 return <section className="shared-panel" aria-label="Live workout feed">
  <h2>Live activity</h2>
  <div className="watch-connections" role="status" aria-live="polite">
   {Object.entries(connections).map(([app,connection])=>{
    const view=error?{connected:false,label:'Not connected',detail:'Dashboard offline, retrying'}:connection;
    return <div key={app} className={`watch-connection${view.connected?'':' off'}`}>
     <span className="dot" aria-hidden="true" />
     <div><strong>{app==='pacepilot'?'PacePilot':'Gut Train'}</strong>
      <span className="watch-connection-label">{view.label}</span>
      <span className="watch-connection-detail">{view.detail}</span>
     </div>
    </div>;
   })}
  </div>
  <p>Watch updates about every 5 seconds; this panel checks every 2 seconds. Phone connectivity can add delay.</p>
  {error&&<p role="status">Connection unavailable. Showing the last received activity.</p>}
  {!persistent&&<p>Temporary local storage: activity may reset when the server restarts.</p>}
  {!streams.length&&<p>Waiting for a workout. Enable “Share live + summary” on your watch, then start a session with your phone connected.</p>}
  {streams.map(s=>{
   const state=liveState(s,now),fresh=state==='active'&&!error,stress=stressView(s,now);
   return <article key={s.app+':'+s.mode} className="live-workout">
    <h3>{s.app==='pacepilot'?'PacePilot':'Gut Train'} {s.mode==='DEMO'?'· DEMO':''} · {state==='stale'?'Signal stale':state}</h3>
    <p><strong>{fresh&&s.heartRate!=null?s.heartRate+' bpm':'HR unavailable'}</strong> · {clock(s.elapsedSec)} elapsed</p>
    <p>Last update {Math.max(0,Math.floor(now-s.receivedAt))} seconds ago · Session {s.sessionId}</p>
    <LiveRunner session={s} now={now} offline={error}/>
    <dl className="shared-facts">
     <div className="stress-fact"><dt>Stress</dt><dd>
      {stress ? stress.fresh ? <>{stress.value} · {stress.band}<small>read {ageLabel(stress.ageSec)}</small></> :
       <>Last reading {stress.value} · {stress.band}, {ageLabel(stress.ageSec)}</> :
       <>No reading<small>Garmin pauses stress readings during hard effort.</small></>}
     </dd></div>
     {s.goalSec!=null&&<div><dt>Goal</dt><dd>{clock(s.goalSec)}</dd></div>}
     {s.movingSec!=null&&<div><dt>Estimated moving</dt><dd>{clock(s.movingSec)}</dd></div>}
     {s.distanceM!=null&&<div><dt>Distance</dt><dd>{(s.distanceM/1000).toFixed(2)} km</dd></div>}
     {s.speedMps!=null&&<div><dt>Last speed</dt><dd>{(s.speedMps*3.6).toFixed(1)} km/h</dd></div>}
     {s.carbsG!=null&&<div><dt>Carbs logged</dt><dd>{s.carbsG} g</dd></div>}
     {s.fluidMl!=null&&<div><dt>Drinks logged</dt><dd>{s.fluidMl} ml</dd></div>}
    </dl>
    <HeartRateChart samples={s.samples}/>
    <p>Recent heart rate · up to 10 minutes. Missing readings remain gaps.</p>
   </article>;
  })}
 </section>;
}
