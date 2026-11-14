import { listLive, upsertLive, isPersistent } from '../../../lib/store';
import { normalizeLive } from '../../../lib/live';
export const dynamic='force-dynamic';
const headers={'Cache-Control':'no-store, max-age=0'};
export async function GET() {
  try {return Response.json({streams:await listLive(),serverNow:Math.floor(Date.now()/1000),persistent:isPersistent},{headers});}
  catch {return Response.json({error:'Live feed unavailable'},{status:503,headers});}
}
export async function POST(request) {
  if(process.env.INGEST_KEY && request.headers.get('x-api-key')!==process.env.INGEST_KEY) return Response.json({error:'Invalid API key'},{status:401,headers});
  let packet;
  try {packet=normalizeLive(await request.json());} catch {return Response.json({error:'Invalid live packet'},{status:400,headers});}
  try {return Response.json({accepted:await upsertLive(packet)},{status:200,headers});}
  catch {return Response.json({error:'Live feed unavailable'},{status:503,headers});}
}
