// Take dashboard, incidents, landing, and docs screenshots
// at desktop (1440x900) and mobile (375x812) viewports.
// Robust waits for premium DB-backed UI (Operations Fabric, xyOps Evidence, Gate panels).
// Use: BASE_URL=http://127.0.0.1:3456 node scripts/screenshot.js
// Pre-seed locked state with: make reset-demo && curl .../inject-failures && curl .../evaluate

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3456';
const OUT = path.resolve(__dirname, '..', 'screenshots');

const TARGETS = [
  { name: 'dashboard', url: '/dashboard', waitFor: 'text=Operations Fabric' },
  { name: 'incidents', url: '/incidents', waitFor: 'text=xyOps Evidence' },
  { name: 'landing', url: '/', waitFor: 'text=CellGuard' },
  { name: 'docs', url: '/runbooks/gameday', waitFor: 'text=Game Day' }
];

async function waitForPremiumUI(page, waitForText) {
  // Core load + network
  await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
  // Wait for key premium element (Operations Fabric / xyOps Evidence / hero text)
  if (waitForText) {
    await page.waitForSelector(waitForText, { timeout: 15000, state: 'visible' }).catch(() => {});
  }
  // Force full layout paint of tall dense UI (critical for fullPage captures of evidence panels)
  await page.evaluate(async () => {
    window.scrollTo(0, document.body.scrollHeight || 1800);
    await new Promise(r => setTimeout(r, 450));
    window.scrollTo(0, 0);
    await new Promise(r => setTimeout(r, 300));
  });
  // Extra beat for Hotwire/Turbo streams, GSAP inits, icon fonts, Tailwind painted panels
  await page.waitForTimeout(1200);
  // Ensure no obvious skeleton if present
  await page.waitForSelector('.cg-skeleton', { state: 'hidden', timeout: 3000 }).catch(() => {});
}

async function shoot(viewport, label) {
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu', '--font-render-hinting=none'] });
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: 2,
    // Reduce motion + consistent fonts for deterministic premium screenshots
    reducedMotion: 'reduce',
    colorScheme: 'dark'
  });
  const page = await context.newPage();

  // Surface console errors from page (helps debug "other errors from the images")
  page.on('console', msg => { if (msg.type() === 'error') console.error(`[page:${label}] ${msg.text()}`); });
  page.on('pageerror', err => console.error(`[pageerr:${label}] ${err.message}`));

  for (const t of TARGETS) {
    const file = path.join(OUT, `${t.name}-${label}.png`);
    console.log(`[${label}] ${t.url} -> ${file}`);
    try {
      await page.goto(BASE + t.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await waitForPremiumUI(page, t.waitFor);
      // For dashboard/incidents, scroll a bit to ensure lower panels paint (dense UI)
      if (t.name === 'dashboard' || t.name === 'incidents') {
        await page.evaluate(() => window.scrollBy(0, 120));
        await page.waitForTimeout(400);
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.waitForTimeout(300);
      }
      await page.screenshot({ path: file, fullPage: true });
    } catch (e) {
      console.error(`  failed: ${e.message}`);
      // Capture debug evidence even on failure
      try {
        const errFile = path.join(OUT, `error-${t.name}-${label}.png`);
        await page.screenshot({ path: errFile, fullPage: true });
        console.error(`  saved debug: ${errFile}`);
      } catch (_) {}
    }
  }

  await browser.close();
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  console.log(`Screenshots targeting ${BASE} (ensure demo server + seeded state for locked evidence)`);
  await shoot({ width: 1440, height: 1200 }, 'desktop');  // taller to fit dense premium panels + full gate xyops evidence
  await shoot({ width: 375, height: 900 }, 'mobile');
  console.log('done');
})();
