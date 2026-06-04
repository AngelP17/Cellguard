// Take canonical landing and incidents screenshots
// at desktop (1440x900) and mobile (375x812) viewports.
// Dashboard state screenshots are owned by screenshot-open.js and screenshot-locked.js.
// Use: BASE_URL=http://127.0.0.1:3456 node scripts/screenshot.js

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3456';
const OUT = path.resolve(__dirname, '..', 'screenshots');

const TARGETS = [
  { name: 'incidents', url: '/incidents', waitFor: 'text=xyOps Evidence' },
  { name: 'landing', url: '/', waitFor: 'text=CellGuard' }
];

function seedOpenState() {
  console.log('[screenshots] ensuring open gate with xyOps evidence for landing and incidents...');
  try {
    execSync(`cd ${__dirname}/.. && RBENV_VERSION=3.3.0 rbenv exec bundle exec rails runner '
      shard=Shard.find_or_create_by!(name:"shard-default");
      Xyops::Simulator.reset! rescue nil;
      JobStat.where(shard: shard).delete_all;
      XyopsAlert.delete_all rescue nil;
      XyopsWorkflowRun.delete_all rescue nil;
      XyopsSnapshot.delete_all rescue nil;
      b=shard.error_budget || shard.build_error_budget;
      b.update!(budget_consumed:0.0, budget_remaining:1.0, current_burn_rate:0.0, release_gate_open:true, violation_started_at:nil, evaluated_at:Time.current);
      puts "seeded open: gate=#{b.release_gate_open}"
    ' 2>&1 | tail -1`, { stdio: 'pipe', timeout: 30000 });
    execSync(`curl -s -X POST '${BASE}/api/inject-failures' -H 'Content-Type: application/json' -d '{"shard":"shard-default","queue":"default","minutes":5,"error_rate":0.15,"total":2000,"p95_latency_ms":650}' > /dev/null 2>&1 || true`, { stdio: 'ignore', timeout: 10000 });
    execSync(`cd ${__dirname}/.. && RBENV_VERSION=3.3.0 rbenv exec bundle exec rails runner '
      shard=Shard.find_by!(name:"shard-default");
      b=shard.error_budget;
      b.update!(budget_consumed:0.0, budget_remaining:1.0, current_burn_rate:0.0, release_gate_open:true, violation_started_at:nil, evaluated_at:Time.current);
      puts "seeded evidence with open gate"
    ' 2>&1 | tail -1`, { stdio: 'pipe', timeout: 30000 });
  } catch (e) {
    console.log('[screenshots] open seed note:', e.message);
  }
}

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

  // Surface console errors from page.
  page.on('console', msg => { if (msg.type() === 'error') console.error(`[page:${label}] ${msg.text()}`); });
  page.on('pageerror', err => console.error(`[pageerr:${label}] ${err.message}`));

  for (const t of TARGETS) {
    const file = path.join(OUT, `${t.name}-${label}.png`);
    console.log(`[${label}] ${t.url} -> ${file}`);
    try {
      await page.goto(BASE + t.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await waitForPremiumUI(page, t.waitFor);
      if (t.name === 'incidents') {
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
  seedOpenState();
  console.log(`Screenshots targeting ${BASE}`);
  await shoot({ width: 1440, height: 1200 }, 'desktop');
  await shoot({ width: 375, height: 900 }, 'mobile');
  console.log('done');
})();
