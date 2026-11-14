import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,mkdtemp,access,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createServer} from 'node:net';
import {randomUUID} from 'node:crypto';
import {spawn,execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec=promisify(execFile);
const moduleUrl=source=>'data:text/javascript;base64,'+Buffer.from(source).toString('base64');

test('real Redis atomically orders live packets, retains history and isolates channels',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'garmin-redis-'));
 const listener=createServer();
 await new Promise((resolve,reject)=>{listener.once('error',reject);listener.listen(0,'127.0.0.1',resolve);});
 const port=listener.address().port;await new Promise(resolve=>listener.close(resolve));
 const password=randomUUID();
 const server=spawn('redis-server',['--bind','127.0.0.1','--port',String(port),'--requirepass',password,'--save','','--appendonly','no'],{stdio:['ignore','pipe','pipe']});
 let launchLog='';server.stdout.on('data',chunk=>launchLog+=chunk);server.stderr.on('data',chunk=>launchLog+=chunk);
 const exited=new Promise(resolve=>{server.once('exit',resolve);server.once('error',resolve);});
 const previousFetch=globalThis.fetch;
 try {
  let ready=false;
  for(let i=0;i<100;i++){if(launchLog.includes('Ready to accept connections')){ready=true;break;}await new Promise(resolve=>setTimeout(resolve,25));}
  assert.ok(ready,'Redis did not start: '+launchLog);
  async function command(args){const r=await exec('redis-cli',['-h','127.0.0.1','-p',String(port),'-a',password,'--no-auth-warning','--json',...args.map(String)]);return JSON.parse(r.stdout);}
  // Route the production store's REST commands to an isolated real Redis.
  // No external endpoint or production data is used; the temporary server is password-protected on loopback.
  globalThis.fetch=async(_url,options)=>Response.json({result:await command(JSON.parse(options.body))});
  const source=(await readFile(new URL('./store.js',import.meta.url),'utf8'))
   .replace(/const redisUrl = .*;/,"const redisUrl = 'http://isolated-redis.test';")
   .replace(/const redisToken = .*;/,"const redisToken = 'local-test';");
  const store=await import(moduleUrl(source));
  const packet={app:'pacepilot',mode:'LIVE',sessionId:100,sequence:1,status:'active',sampledAt:100,heartRate:130};
  assert.equal(await store.upsertLive(packet,100),true);
  assert.equal(await store.upsertLive(packet,101),false);
  await Promise.all([5,3,4].map(sequence=>store.upsertLive({...packet,sequence},105)));
  let row=(await store.listLive(106))[0];assert.equal(row.sequence,5);
  assert.equal(await store.upsertLive({...packet,sequence:6,status:'completed'},106),true);
  assert.equal(await store.upsertLive({...packet,sequence:7},107),false);
  assert.equal(await store.upsertLive({...packet,sessionId:99,sequence:99},107),false);
  for(let sequence=1;sequence<=125;sequence++) await store.upsertLive({...packet,sessionId:101,sequence},110);
  await store.upsertLive({...packet,mode:'DEMO'},110);
  await store.upsertLive({...packet,app:'guttrain'},110);
  const rows=await store.listLive(111);assert.equal(rows.length,3);
  row=rows.find(x=>x.app==='pacepilot'&&x.mode==='LIVE');
  assert.equal(row.samples.length,120);assert.equal(row.samples[0].sequence,6);
  assert.ok((await command(['TTL','garmin:live:v1']))>0);
 } finally {
  globalThis.fetch=previousFetch;
  server.kill('SIGTERM');await exited;await rm(dir,{recursive:true,force:true});
 }
});
