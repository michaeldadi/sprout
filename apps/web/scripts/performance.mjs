import { chromium } from '@playwright/test';
import { writeFile } from 'node:fs/promises';
const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  isMobile: true,
  deviceScaleFactor: 1,
});
const cdp = await page.context().newCDPSession(page);
await cdp.send('Network.enable');
await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
await cdp.send('Network.emulateNetworkConditions', {
  offline: false,
  latency: 150,
  downloadThroughput: (1600 * 1024) / 8,
  uploadThroughput: (750 * 1024) / 8,
});
await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
await page.addInitScript(() => {
  window.__metrics = { lcp: 0, cls: 0, tbt: 0 };
  new PerformanceObserver((list) => {
    for (const item of list.getEntries()) window.__metrics.lcp = item.startTime;
  }).observe({ type: 'largest-contentful-paint', buffered: true });
  new PerformanceObserver((list) => {
    for (const item of list.getEntries())
      if (!item.hadRecentInput) window.__metrics.cls += item.value;
  }).observe({ type: 'layout-shift', buffered: true });
  new PerformanceObserver((list) => {
    for (const item of list.getEntries())
      window.__metrics.tbt += Math.max(0, item.duration - 50);
  }).observe({ type: 'longtask', buffered: true });
});
await page.goto('http://127.0.0.1:3000');
await page.locator('html[data-hydrated=true]').waitFor();
await page.waitForTimeout(6000);
const metrics = await page.evaluate(() => ({
  ...window.__metrics,
  resources: performance.getEntriesByType('resource').map((r) => ({
    name: new URL(r.name).pathname,
    transferSize: r.transferSize,
    encodedBodySize: r.encodedBodySize,
    duration: r.duration,
  })),
  navigation: performance.getEntriesByType('navigation').map((n) => ({
    responseStart: n.responseStart,
    domContentLoaded: n.domContentLoadedEventEnd,
    load: n.loadEventEnd,
  })),
}));
await writeFile(
  '../../docs/web/evidence/performance.json',
  JSON.stringify(
    {
      profile: {
        width: 390,
        cpuSlowdown: 4,
        latencyMs: 150,
        downloadKbps: 1600,
      },
      metrics,
    },
    null,
    2
  )
);
console.log(JSON.stringify(metrics, null, 2));
await browser.close();
