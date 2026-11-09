import { chromium } from '@playwright/test';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
const origin = process.env.CAPTURE_ORIGIN || 'http://127.0.0.1:3000';
const output = '../../docs/web/evidence';
await mkdir(output, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage();
const problems = [];
page.on('pageerror', (error) => problems.push(error.message));
const fontCss = (
  (await readFile('src/styles.css', 'utf8')).match(/@font-face\s*\{[^}]+\}/g) ||
  []
).join('\n');
let reference = await readFile(
  '../../docs/web/reference/clear-sky.html',
  'utf8'
);
reference = reference
  .replace(/<link rel="preconnect"[^>]*>/g, '')
  .replace(
    /<link href="https:\/\/fonts.googleapis.com[^>]*>/g,
    `<style>${fontCss}</style>`
  );
await page.route('**/cdn.tailwindcss.com/**', async (route) =>
  route.fulfill({
    body: await readFile(
      '../../docs/web/reference/tailwind-runtime.js',
      'utf8'
    ),
    contentType: 'application/javascript',
  })
);
await page.route('https://cdn.tailwindcss.com/', async (route) =>
  route.fulfill({
    body: await readFile(
      '../../docs/web/reference/tailwind-runtime.js',
      'utf8'
    ),
    contentType: 'application/javascript',
  })
);
await page.route('**/__reference', (route) =>
  route.fulfill({ body: reference, contentType: 'text/html' })
);
const measurements = {};
for (const width of [1440, 834, 390]) {
  await page.setViewportSize({ width, height: 900 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  for (const [name, path] of [
    ['reference', '/__reference'],
    ['implementation', '/'],
  ]) {
    await page.goto(origin + path);
    if (name === 'implementation')
      await page.locator('html[data-hydrated=true]').waitFor();
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(700);
    await page.evaluate(() =>
      document.querySelectorAll('.reveal').forEach((e) => e.classList.add('in'))
    );
    await page.screenshot({
      path: `${output}/${name}-${width}.png`,
      fullPage: true,
    });
    measurements[`${name}-${width}`] = await page.evaluate(() => ({
      height: document.documentElement.scrollHeight,
      overflow: document.documentElement.scrollWidth > innerWidth,
      sections: [
        ...document.querySelectorAll('body > section,main > section,footer'),
      ].map((el) => ({
        name: el.getAttribute('data-aid'),
        top: el.getBoundingClientRect().top + scrollY,
        height: el.getBoundingClientRect().height,
      })),
      heading: getComputedStyle(document.querySelector('h1')).fontFamily,
    }));
  }
}
await page.setViewportSize({ width: 1200, height: 630 });
await page.setContent(
  `<html><style>${fontCss}*{box-sizing:border-box}body{margin:0;background:#F6F8F4;color:#16271D;font-family:Inter;padding:62px 80px;background-image:radial-gradient(circle,#1c6a3d12 1px,transparent 1px),radial-gradient(ellipse at top left,#d8ecdd,transparent 70%);background-size:24px 24px,100% 100%}header{display:flex;gap:15px;align-items:center;font-size:30px;font-weight:600}img{width:52px;height:52px}h1{font:400 82px/1.03 Fraunces;margin:66px 0 30px;letter-spacing:-.02em}em{color:#1c6a3d}p{color:#526258;font-size:20px}</style><body><header><img src="${origin}/brand/sprout-app-icon.svg">sprout</header><h1>Money that finally<br><em>explains itself.</em></h1><p>Personal finance · iPhone & Android</p></body></html>`
);
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: 'public/social.png' });
await writeFile(
  `${output}/measurements.json`,
  JSON.stringify({ measurements, problems }, null, 2)
);
console.log(JSON.stringify({ measurements, problems }, null, 2));
await browser.close();
