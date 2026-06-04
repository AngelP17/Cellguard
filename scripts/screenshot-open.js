// Take canonical "open gate" dashboard screenshots for README evidence.
// Self-seeds a clean open state (no fabric degradation) before capture.

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3456';
const OUT = path.resolve(__dirname, '..', 'screenshots');

function seedOpen() {
  console.log('[open] ensuring clean open state...');
  try {
    // Use curl against the demo server (ALLOW_DEMO_ENDPOINTS enables without token)
    execSync(`curl -s -X POST '${BASE}/api/inject-failures' -H 'Content-Type: application/json' -d '{"shard":"shard-default","error_rate":0,"total":0}' > /dev/null 2>&1 || true`, { stdio: 'ignore' });
    // Force open via direct budget reset (runner)
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
  } catch (e) { console.log('[open] seed note:', e.message); }
}

async function waitForOpenUI(page) {
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  await page.waitForSelector('text=Operations Fabric', { timeout: 12000, state: 'visible' }).catch(() => {});
  await page.waitForSelector('text=OPEN', { timeout: 8000, state: 'visible' }).catch(() => {});
  // Force paint of full content
  await page.evaluate(async () => {
    window.scrollTo(0, document.body.scrollHeight || 1600);
    await new Promise(r => setTimeout(r, 400));
    window.scrollTo(0, 0);
    await new Promise(r => setTimeout(r, 250));
  });
  await page.waitForTimeout(900);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  seedOpen();
  const browser = await chromium.launch({ headless: true, args: ['--disable-gpu'] });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1200 }, deviceScaleFactor: 2, reducedMotion: 'reduce', colorScheme: 'dark' });
  const page = await context.newPage();
  page.on('console', m => { if (m.type()==='error') console.error('[page open]', m.text()); });
  await page.goto(BASE + '/dashboard', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitForOpenUI(page);
  await page.screenshot({ path: path.join(OUT, 'dashboard-open.png'), fullPage: true });
  await page.setViewportSize({ width: 375, height: 900 });
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitForOpenUI(page);
  await page.screenshot({ path: path.join(OUT, 'dashboard-mobile.png'), fullPage: true });
  await browser.close();
  console.log('dashboard-open.png and dashboard-mobile.png captured (canonical open state)');
})();
