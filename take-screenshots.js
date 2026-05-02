const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  const port = process.env.PORT || '3001';
  const base = `http://localhost:${port}`;

  const pages = [
    { url: `${base}/`, name: 'landing', wait: 2500, scroll: true },
    { url: `${base}/dashboard`, name: 'dashboard', wait: 2000, scroll: false },
    { url: `${base}/incidents`, name: 'incidents', wait: 1500, scroll: false },
  ];

  for (const p of pages) {
    await page.goto(p.url, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1200);

    if (p.scroll) {
      await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' }));
      await page.waitForTimeout(800);
      await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
      await page.waitForTimeout(p.wait);
    } else {
      await page.waitForTimeout(p.wait);
    }

    await page.screenshot({ path: `./screenshots/${p.name}.png`, fullPage: true });
    console.log(`Screenshot: ${p.name}.png`);
  }

  await browser.close();
})();
