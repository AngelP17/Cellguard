const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUT = path.resolve(__dirname, 'screenshots');
const port = process.env.PORT || '3456';
const BASE = process.env.BASE_URL || `http://127.0.0.1:${port}`;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu'] });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1200 }, deviceScaleFactor: 2, reducedMotion: 'reduce', colorScheme: 'dark' });

  const pages = [
    { url: `${BASE}/`, name: 'landing-desktop', waitFor: 'text=CellGuard' },
    { url: `${BASE}/dashboard`, name: 'dashboard-desktop', waitFor: 'text=Operations Fabric' },
    { url: `${BASE}/incidents`, name: 'incidents-desktop', waitFor: 'text=xyOps Evidence' },
  ];

  for (const p of pages) {
    console.log(`[take] ${p.url}`);
    await page.goto(p.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    if (p.waitFor) {
      await page.waitForSelector(p.waitFor, { timeout: 12000, state: 'visible' }).catch(() => {});
    }
    await page.waitForTimeout(900);
    await page.screenshot({ path: path.join(OUT, `${p.name}.png`), fullPage: true });
    console.log(`Screenshot: ${p.name}.png`);
  }

  await browser.close();
})();
