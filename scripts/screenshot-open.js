// Take an "open gate" dashboard screenshot
// for the README and the docs/VERIFICATION.md evidence.

const { chromium } = require('playwright');
const path = require('path');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const OUT = path.resolve(__dirname, '..', 'screenshots');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  const page = await context.newPage();
  await page.goto(BASE + '/dashboard', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, 'dashboard-open.png'), fullPage: false });
  await browser.close();
  console.log('dashboard-open.png captured');
})();
