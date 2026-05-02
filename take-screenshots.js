const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  const pages = [
    { url: 'http://localhost:3001/', name: 'landing' },
    { url: 'http://localhost:3001/dashboard', name: 'dashboard' },
    { url: 'http://localhost:3001/incidents', name: 'incidents' },
  ];

  for (const p of pages) {
    await page.goto(p.url, { waitUntil: 'networkidle' });
    await page.screenshot({ path: `./screenshots/${p.name}.png`, fullPage: true });
    console.log(`Screenshot: ${p.name}.png`);
  }

  await browser.close();
})();
