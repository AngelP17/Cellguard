// Take "locked gate" and "open gate" dashboard screenshots
// for the README and the docs/VERIFICATION.md evidence.

const { chromium } = require('playwright');
const path = require('path');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const OUT = path.resolve(__dirname, '..', 'screenshots');

async function shoot(url, file, viewport) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto(BASE + url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: file, fullPage: false });
  await browser.close();
  console.log(`${file} captured`);
}

(async () => {
  await shoot('/dashboard', path.join(OUT, 'dashboard-locked.png'), { width: 1440, height: 900 });
})();
