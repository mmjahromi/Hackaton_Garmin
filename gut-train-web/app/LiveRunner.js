import {liveInsights} from '../lib/liveInsights';
export default function LiveRunner({session,now,offline}) {
 const view=liveInsights(session,now,offline);
 return <div className="live-coach">
  <div className={`live-runner ${view.moving?'is-moving':''}`}>
   <svg viewBox="0 0 160 160" role="img" aria-label={`Illustrative runner: ${view.label}. Animation is not measured gait.`}>
    <ellipse cx="80" cy="148" rx="55" ry="4" fill="currentColor" opacity=".12"/>
    <g fill="none" stroke="currentColor" strokeWidth="9" strokeLinecap="round" strokeLinejoin="round">
     <circle cx="91" cy="27" r="12" fill="currentColor" stroke="none"/>
     <path d="M85 49 L72 86"/>
     <path className="runner-arm" d="M84 52 L58 62 L43 48 M83 53 L104 72 L125 62"/>
     <path className="runner-leg" d="M72 86 L101 109 L120 136 M72 86 L55 117 L30 125"/>
    </g>
   </svg>
   <strong>{view.label}</strong><small>Illustrative movement, not gait analysis</small>
  </div>
  <div><h4>Live insights</h4>
   {view.progress!==null&&<><progress max="100" value={view.progress} aria-label="Recorded workout goal progress"/><p>{view.progress}% recorded · {Math.ceil(view.remaining/60)} min remaining</p></>}
   <ul>{view.notes.map(note=><li key={note}>{note}</li>)}</ul>
   <p className="fine">Follow your watch’s coaching cues. This panel does not infer recovery or prescribe effort from stress or heart rate alone.</p>
  </div>
 </div>;
}
