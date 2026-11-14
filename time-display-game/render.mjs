// Renders index.html frame by frame into concept.mp4 (30 s, 30 fps, 1280x720).
// Usage: node render.mjs
// Needs ffmpeg on PATH and playwright-core (set PLAYWRIGHT_CORE to its folder if not found).
import { createRequire } from 'node:module';
import { spawn, execSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const globalRoot = execSync('npm root -g').toString().trim();
const pwPath = process.env.PLAYWRIGHT_CORE || path.join(globalRoot, '@playwright/cli/node_modules/playwright-core');
const { chromium } = require(pwPath);

const FPS = 30, SECONDS = 30, FRAMES = FPS * SECONDS;
const out = path.join(here, 'concept.mp4');

let browser;
try { browser = await chromium.launch(); }
catch { browser = await chromium.launch({ channel: 'chrome' }); }
const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(path.join(here, 'index.html')).href + '#export');

const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-',
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17', '-preset', 'medium', '-movflags', '+faststart', out],
  { stdio: ['pipe', 'inherit', 'inherit'] });
const done = new Promise((res, rej) => ff.on('close', c => (c === 0 ? res() : rej(new Error('ffmpeg exited ' + c)))));

for (let i = 0; i < FRAMES; i++) {
  const b64 = await page.evaluate(n => { window.renderFrame(n); return document.getElementById('c').toDataURL('image/png').split(',')[1]; }, i);
  if (!ff.stdin.write(Buffer.from(b64, 'base64'))) await new Promise(r => ff.stdin.once('drain', r));
  if (i % 150 === 0) console.log(`frame ${i}/${FRAMES}`);
}
ff.stdin.end();
await done;
await browser.close();
console.log('wrote', out);
