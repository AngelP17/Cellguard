// Take canonical "locked gate" dashboard screenshot with xyOps fabric evidence.
// Self-seeds the full degradation + evaluate so gate is 423 + DB-backed evidence (nightly-fulfillment-sync etc).

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3456';
const OUT = path.resolve(__dirname, '..', 'screenshots');

function seedLocked() {
  console.log('[locked] seeding full xyOps degradation for evidence panels...');
  try {
    execSync(`curl -s -X POST '${BASE}/api/inject-failures' -H 'Content-Type: application/json' -d '{"shard":"shard-default","queue":"default","minutes":5,"error_rate":0.15,"total":2000,"p95_latency_ms":650}' > /dev/null 2>&1 || true`, { stdio: 'ignore' });
    execSync(`curl -s -X POST '${BASE}/api/evaluate' -H 'Content-Type: application/json' -d '{"shard":"shard-default","window_minutes":60}' > /dev/null 2>&1 || true`, { stdio: 'ignore' });
    // Confirm via runner (ensures budget + links)
    const summary = execSync(`cd ${__dirname}/.. && RBENV_VERSION=3.3.0 rbenv exec bundle exec rails runner '
      b=Shard.find_by(name:"shard-default")&.error_budget;
      puts "locked_seed: open=#{b&.release_gate_open} runs=#{XyopsWorkflowRun.failed.count} snaps=#{XyopsSnapshot.count}"
    ' 2>&1 | tail -1`, { stdio: 'pipe', timeout: 30000 });
    const check = execSync(`curl -s '${BASE}/api/release-gate/check?shard=shard-default'`, { encoding: 'utf8', timeout: 10000 });
    const allowed = JSON.parse(check).allowed;
    if (allowed !== false) {
      throw new Error(`locked seed failed: expected allowed=false, got ${allowed}; ${summary.toString().trim()}`);
    }
  } catch (e) {
    console.error('[locked] seed failed:', e.message);
    process.exit(1);
  }
}

async function waitForLockedUI(page) {
  await page.waitForLoadState('networkidle', { timeout: 18000 }).catch(() => {});
  await page.waitForSelector('text=XYOPS FABRIC EVIDENCE', { timeout: 12000, state: 'visible' });
  await page.waitForSelector('text=423 LOCKED', { timeout: 8000, state: 'visible' });
  await page.waitForSelector('text=nightly-fulfillment-sync', { timeout: 6000, state: 'visible' });
  // Force paint of lower dense content (Hotwire, charts, long lists)
  await page.evaluate(async () => {
    window.scrollTo(0, document.body.scrollHeight || 2000);
    await new Promise(r => setTimeout(r, 500));
    window.scrollTo(0, 0);
    await new Promise(r => setTimeout(r, 300));
  });
  await page.waitForTimeout(1100);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  seedLocked();
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu'] });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1200 }, deviceScaleFactor: 2, reducedMotion: 'reduce', colorScheme: 'dark' });
  const page = await context.newPage();
  page.on('console', m => { if (m.type()==='error') console.error('[page locked]', m.text()); });
  await page.goto(BASE + '/dashboard', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitForLockedUI(page);
  await page.screenshot({ path: path.join(OUT, 'dashboard-locked.png'), fullPage: true });
  await browser.close();
  console.log('dashboard-locked.png captured (canonical locked state)');
})();
