import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const url=s=>'data:text/javascript;base64,'+Buffer.from(s).toString('base64');
const liveUrl=url(await readFile(new URL('./live.js',import.meta.url),'utf8'));
const {normalizeLive,liveState,hrSegments,stressView,connectionView}=await import(liveUrl);
const storeUrl=url((await readFile(new URL('./store.js',import.meta.url),'utf8')).replace(/const redisUrl = .*;/,'const redisUrl = null;').replace(/const redisToken = .*;/,'const redisToken = null;'));
const store=await import(storeUrl);
const api=await import(url((await readFile(new URL('../app/api/live/route.js',import.meta.url),'utf8')).replace("'../../../lib/store'",JSON.stringify(storeUrl)).replace("'../../../lib/live'",JSON.stringify(liveUrl))));
const packet={schemaVersion:1,app:'pacepilot',mode:'LIVE',status:'active',sessionId:100,sequence:1,sampledAt:100,elapsedSec:10,heartRate:130,movingSec:8,goalSec:1200};
const request=body=>new Request('http://localhost/api/live',{method:'POST',body:JSON.stringify(body)});
test('live validation preserves missing HR and strips unknown fields',()=>{
 const value=normalizeLive({...packet,heartRate:null,privateData:'ignored'});
 assert.equal(value.heartRate,null);assert.equal(value.privateData,undefined);
 assert.equal(normalizeLive({...packet,status:'paused'}).heartRate,null);
 assert.equal(normalizeLive({...packet,status:'completed'}).heartRate,null);
});
test('live endpoint rejects malformed packets',async()=>{
 for(const body of [null,[],{}, {...packet,app:'bad'},{...packet,mode:'bad'},{...packet,heartRate:0},{...packet,sequence:-1},{...packet,movingSec:11},{...packet,elapsedSec:'10'}]) assert.equal((await api.POST(request(body))).status,400);
 assert.equal((await api.POST(new Request('http://localhost/api/live',{method:'POST',body:'{'}))).status,400);
});
test('live ordering ignores duplicates and delayed previous sessions',async()=>{
 const p=normalizeLive(packet);
 assert.equal(await store.upsertLive(p,100),true);
 assert.equal(await store.upsertLive(p,101),false);
 assert.equal(await store.upsertLive({...p,sequence:2,heartRate:140},105),true);
 assert.equal(await store.upsertLive({...p,sessionId:99,sequence:99},106),false);
 const row=(await store.listLive(106))[0];assert.equal(row.heartRate,140);assert.equal(row.samples.length,2);
});
test('completion cannot be reopened by delayed active packets',async()=>{
 const p=normalizeLive({...packet,status:'completed',sequence:3});
 assert.equal(await store.upsertLive(p,110),true);
 assert.equal(await store.upsertLive(normalizeLive({...packet,sequence:4}),111),false);
 assert.equal((await store.listLive(111))[0].status,'completed');
});
test('live channels isolate app and demo, bound history and expire old records',async()=>{
 for(let sequence=1;sequence<=130;sequence++) await store.upsertLive(normalizeLive({...packet,sessionId:101,sequence}),200+sequence);
 await store.upsertLive(normalizeLive({...packet,mode:'DEMO'}),330);
 await store.upsertLive(normalizeLive({...packet,app:'guttrain'}),330);
 const rows=await store.listLive(331);assert.equal(rows.length,3);
 const live=rows.find(s=>s.app==='pacepilot'&&s.mode==='LIVE');assert.equal(live.samples.length,120);assert.equal(live.samples[0].sequence,11);
 assert.equal((await store.listLive(100000)).length,0);
});
test('feed staleness uses server reception and sample time without faking completion',()=>{
 const row={...packet,receivedAt:100};
 assert.equal(liveState(row,120),'active');assert.equal(liveState(row,121),'stale');
 assert.equal(liveState({...row,receivedAt:200},200),'stale');
 assert.equal(liveState({...row,status:'paused'},105),'paused');
 assert.equal(liveState({...row,status:'completed'},1000),'completed');
 assert.equal(liveState({...row,sampledAt:1000},100),'stale');
});
test('HR chart keeps sensor loss and long gaps separate',()=>{
 const a={status:'active',heartRate:130,sampledAt:100};
 assert.deepEqual(hrSegments([a,{...a,heartRate:null,sampledAt:105},{...a,sampledAt:110},{...a,sampledAt:140}]).map(x=>x.length),[1,1,1]);
});
test('live GET is uncached and includes server clock; POST honors ingestion key',async()=>{
 const get=await api.GET();assert.match(get.headers.get('cache-control'),/no-store/);
 assert.ok(Number.isInteger((await get.json()).serverNow));
 const prev=process.env.INGEST_KEY;process.env.INGEST_KEY='test-only';
 try{assert.equal((await api.POST(request(packet))).status,401);}finally{if(prev===undefined)delete process.env.INGEST_KEY;else process.env.INGEST_KEY=prev;}
});

test('live endpoint reports storage command failures as 503',async()=>{
 const redisSource=(await readFile(new URL('./store.js',import.meta.url),'utf8')).replace(/const redisUrl = .*;/,"const redisUrl = 'https://redis.invalid';").replace(/const redisToken = .*;/,"const redisToken = 'test';");
 const redisApi=await import(url((await readFile(new URL('../app/api/live/route.js',import.meta.url),'utf8')).replace("'../../../lib/store'",JSON.stringify(url(redisSource))).replace("'../../../lib/live'",JSON.stringify(liveUrl))));
 const old=globalThis.fetch;
 globalThis.fetch=async()=>Response.json({error:'simulated Redis error'});
 try {assert.equal((await redisApi.GET()).status,503);assert.equal((await redisApi.POST(request(packet))).status,503);}
 finally {globalThis.fetch=old;}
});

test('stress validation accepts optional readings and exact bounds',()=>{
 for(const fields of [{},{stress:null,stressAt:null},{stress:0,stressAt:0},{stress:100,stressAt:160}]) {
  const result=normalizeLive({...packet,...fields});
  assert.equal(result.stress,fields.stress??null);
  assert.equal(result.stressAt,fields.stressAt??null);
 }
 for(const status of ['paused','completed']) {
  const result=normalizeLive({...packet,status,stress:34,stressAt:90});
  assert.equal(result.stress,null);assert.equal(result.stressAt,null);
 }
});
test('stress validation rejects missing timestamps, invalid numbers and future readings',()=>{
 for(const fields of [
  {stress:34},{stress:0,stressAt:null},{stress:34,stressAt:161},
  ...[-1,101,1.5,'34',true,NaN,Infinity].map(stress=>({stress,stressAt:90})),
  ...[-1,4102444801,1.5,'90',true,NaN,Infinity].map(stressAt=>({stress:34,stressAt})),
  {stress:null,stressAt:161},
 ]) assert.throws(()=>normalizeLive({...packet,...fields}));
 assert.throws(()=>normalizeLive({...packet,status:'paused',stress:34}));
});
test('stress view labels every band boundary, including zero',()=>{
 for(const [value,band] of [[0,'resting'],[25,'resting'],[26,'low'],[50,'low'],[51,'medium'],[75,'medium'],[76,'high'],[100,'high']])
  assert.deepEqual(stressView({...packet,stress:value,stressAt:90},210),{value,band,ageSec:120,fresh:true});
});
test('stress view ages the actual reading, without carrying missing readings forward',()=>{
 const p={...packet,stress:34,stressAt:0};
 assert.deepEqual(stressView(p,300),{value:34,band:'low',ageSec:300,fresh:true});
 assert.equal(stressView(p,300.1).fresh,false);
 assert.deepEqual(stressView(p,720),{value:34,band:'low',ageSec:720,fresh:false});
 assert.equal(stressView({...p,stressAt:160},100).ageSec,0);
 for(const missing of [null,packet,{...p,stress:null},{...p,stressAt:null},{...p,status:'paused'},{...p,status:'completed'}]) assert.equal(stressView(missing,100),null);
});
test('connection view covers both apps, fresh active and paused, and exact stale threshold',()=>{
 for(const app of ['pacepilot','guttrain']) {
  for(const [status,detail] of [['active','Live now'],['paused','Paused']]) {
   const p={...packet,app,status,receivedAt:100};
   assert.deepEqual(connectionView([p],120)[app],{connected:true,label:'Connected',detail});
   assert.deepEqual(connectionView([p],121)[app],{connected:false,label:'Not connected',detail:'Last seen 21 seconds ago'});
  }
 }
});
test('connection view covers no stream, demo only, completion and stale clocks',()=>{
 const absent={connected:false,label:'Not connected',detail:'No session yet'};
 assert.deepEqual(connectionView([],100),{pacepilot:absent,guttrain:absent});
 assert.deepEqual(connectionView([{...packet,mode:'DEMO',receivedAt:100}],100).pacepilot,absent);
 for(const [fields,now,detail] of [
  [{status:'completed'},220,'Session finished 2 min ago'],
  [{status:'completed'},110,'Session finished 10 seconds ago'],
  [{},820,'Last seen 12 min ago'],
  [{receivedAt:220},220,'Last seen 2 min ago'],
  [{sampledAt:200},200,'Last seen 0 seconds ago'],
  [{sampledAt:161},100,'Last seen 0 seconds ago'],
 ]) assert.deepEqual(connectionView([{...packet,receivedAt:100,...fields}],now).pacepilot,{connected:false,label:'Not connected',detail});
});
test('connection view selects newest LIVE packet without mutating input or letting demos mask it',()=>{
 const old={...packet,receivedAt:100};
 const newest={...old,sequence:2,sampledAt:110,receivedAt:110,status:'completed'};
 const streams=[old,{...newest,mode:'DEMO',status:'active',receivedAt:120},newest];
 const before=JSON.stringify(streams);
 assert.equal(connectionView(streams,120).pacepilot.detail,'Session finished 10 seconds ago');
 assert.equal(connectionView([newest,old],120).pacepilot.connected,false);
 assert.equal(connectionView([old,{...old,sequence:2,status:'paused'}],110).pacepilot.detail,'Paused');
 assert.equal(JSON.stringify(streams),before);
});
test('live API retains stress timestamps in samples and does not carry readings forward',async()=>{
 const p={...packet,sessionId:999,stress:34,stressAt:90};
 assert.equal((await api.POST(request(p))).status,200);
 let row=(await (await api.GET()).json()).streams.find(s=>s.app==='pacepilot'&&s.mode==='LIVE');
 assert.equal(row.stress,34);assert.equal(row.stressAt,90);
 assert.equal(row.samples[0].stress,34);assert.equal(row.samples[0].stressAt,90);
 await api.POST(request({...packet,sessionId:999,sequence:2}));
 row=(await (await api.GET()).json()).streams.find(s=>s.app==='pacepilot'&&s.mode==='LIVE');
 assert.equal(row.stress,null);assert.equal(row.stressAt,null);
 assert.equal(row.samples[0].stress,34);assert.equal(row.samples[1].stress,null);
 assert.equal((await api.POST(request({...p,stressAt:161}))).status,400);
});
