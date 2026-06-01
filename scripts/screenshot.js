// Take dashboard, incidents, landing, and docs screenshots
// at desktop (1440x900) and mobile (375x812) viewports.

const { chromium, devices } = require('playwright');
const path = require('path');
const fs = require('fs');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const OUT = path.resolve(__dirname, '..', 'screenshots');

const TARGETS = [
  { name: 'dashboard', url: '/dashboard' },
  { name: 'incidents', url: '/incidents' },
  { name: 'landing', url: '/' },
  { name: 'docs', url: '/docs' }
];

async function shoot(viewport, label) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport, deviceScaleFactor: 2 });
  const page = await context.newPage();

  for (const t of TARGETS) {
    const file = path.join(OUT, `${t.name}-${label}.png`);
    console.log(`[${label}] ${t.url} -> ${file}`);
    try {
      await page.goto(BASE + t.url, { waitUntil: 'networkidle', timeout: 30000 });
      // Give a beat for hotwire, tailwind, and any deferred loads
      await page.waitForTimeout(800);
      await page.screenshot({ path: file, fullPage: false });
    } catch (e) {
      console.error(`  failed: ${e.message}`);
    }
  }

  await browser.close();
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  await shoot({ width: 1440, height: 900 }, 'desktop');
  await shoot({ width: 375, height: 812 }, 'mobile');
  console.log('done');
})();
