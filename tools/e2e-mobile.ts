/**
 * E2E mobile viewport audit.
 *
 * Запускает headless Chromium, прогоняет приложение через viewport-ы
 * флагманов iPhone и Samsung Galaxy S за 2015–2026, делает скриншоты
 * экранов: menu, online setup, game vs Bot. Складывает в tools/screens/.
 *
 * Использование:
 *   npm run build && (npm run preview -- --port 5180 &) && sleep 1
 *   npx tsx tools/e2e-mobile.ts http://localhost:5180/block-puzzle-pvp/
 *
 * Если префикс /block-puzzle-pvp/ не нужен (dev-сервер) — передай корень.
 */
import { chromium, type Browser, type Page } from "playwright";
import { mkdirSync } from "fs";
import { join } from "path";

interface Device {
  name: string;
  year: number;
  width: number;
  height: number;
  dpr?: number;
  /** Эмулировать safe-area на iPhone — нотч + home indicator. */
  hasNotch?: boolean;
}

// Реальные CSS-viewport-размеры (не физические пиксели) флагманов.
const DEVICES: Device[] = [
  { name: "iphone-6s", year: 2015, width: 375, height: 667, dpr: 2 },
  { name: "galaxy-s6", year: 2015, width: 360, height: 640, dpr: 4 },
  { name: "iphone-7", year: 2016, width: 375, height: 667, dpr: 2 },
  { name: "galaxy-s7", year: 2016, width: 360, height: 640, dpr: 4 },
  { name: "iphone-x", year: 2017, width: 375, height: 812, dpr: 3, hasNotch: true },
  { name: "galaxy-s8", year: 2017, width: 360, height: 740, dpr: 3 },
  { name: "iphone-xs", year: 2018, width: 375, height: 812, dpr: 3, hasNotch: true },
  { name: "galaxy-s9", year: 2018, width: 360, height: 740, dpr: 3 },
  { name: "iphone-11-pro", year: 2019, width: 375, height: 812, dpr: 3, hasNotch: true },
  { name: "galaxy-s10", year: 2019, width: 360, height: 760, dpr: 3 },
  { name: "iphone-12-pro", year: 2020, width: 390, height: 844, dpr: 3, hasNotch: true },
  { name: "galaxy-s20", year: 2020, width: 360, height: 800, dpr: 3 },
  { name: "iphone-13-pro", year: 2021, width: 390, height: 844, dpr: 3, hasNotch: true },
  { name: "galaxy-s21", year: 2021, width: 360, height: 800, dpr: 3 },
  { name: "iphone-14-pro", year: 2022, width: 393, height: 852, dpr: 3, hasNotch: true },
  { name: "galaxy-s22", year: 2022, width: 360, height: 780, dpr: 3 },
  { name: "iphone-15-pro-max", year: 2023, width: 430, height: 932, dpr: 3, hasNotch: true },
  { name: "galaxy-s23", year: 2023, width: 360, height: 780, dpr: 3 },
  { name: "iphone-16-pro-max", year: 2024, width: 440, height: 956, dpr: 3, hasNotch: true },
  { name: "galaxy-s24", year: 2024, width: 360, height: 780, dpr: 3 },
];

const baseUrl = process.argv[2] ?? "http://localhost:5175/";
const screensDir = join(process.cwd(), "tools", "screens");

async function ensureDir(): Promise<void> {
  mkdirSync(screensDir, { recursive: true });
}

async function snap(page: Page, name: string): Promise<void> {
  const path = join(screensDir, `${name}.png`);
  await page.screenshot({ path, fullPage: false });
  console.log("  →", path);
}

async function settle(page: Page, ms = 250): Promise<void> {
  await page.waitForTimeout(ms);
}

async function audit(browser: Browser, device: Device): Promise<void> {
  const tag = `${device.year}-${device.name}`;
  console.log(`\n● ${tag} ${device.width}×${device.height}`);
  const ctx = await browser.newContext({
    viewport: { width: device.width, height: device.height },
    deviceScaleFactor: device.dpr ?? 2,
    isMobile: true,
    hasTouch: true,
    userAgent:
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  });
  const page = await ctx.newPage();

  page.on("console", (m) => {
    if (m.type() === "error" || m.type() === "warning") {
      console.log(`    [${m.type()}] ${m.text()}`);
    }
  });

  try {
    await page.goto(baseUrl, { waitUntil: "networkidle", timeout: 15000 });
    await settle(page, 400);
    await snap(page, `${tag}-01-menu`);

    // Открыть mode-list через .hero-btn (▶ Играть)
    const heroBtn = page.locator(".hero-btn").first();
    if (await heroBtn.isVisible().catch(() => false)) {
      await heroBtn.click();
      await settle(page);
      await snap(page, `${tag}-02-menu-modes`);
    }

    // Зайти в Онлайн
    const onlineMode = page.locator(".mode-btn", { hasText: "Онлайн" }).first();
    if (await onlineMode.isVisible().catch(() => false)) {
      await onlineMode.click();
      await settle(page, 500);
      await snap(page, `${tag}-03-online-setup`);
      // Назад
      const back = page.locator(".back-link").first();
      if (await back.isVisible().catch(() => false)) {
        await back.click();
        await settle(page);
      }
      // Открыть list снова
      if (await heroBtn.isVisible().catch(() => false)) {
        await heroBtn.click();
        await settle(page);
      }
    }

    // Жмём "С ботом"
    const vsBot = page.locator(".mode-btn", { hasText: "С ботом" }).first();
    if (await vsBot.isVisible().catch(() => false)) {
      await vsBot.click();
      await settle(page);
      await snap(page, `${tag}-04-setup`);
      // Жмём Начать
      const start = page.locator(".start-btn").first();
      if (await start.isVisible().catch(() => false)) {
        await start.click();
        await settle(page, 700);
        await snap(page, `${tag}-05-game`);
      }
    }
  } catch (e) {
    console.log(`    ! error: ${e}`);
  } finally {
    await ctx.close();
  }
}

async function main(): Promise<void> {
  await ensureDir();
  const browser = await chromium.launch({ headless: true });
  console.log(`base url: ${baseUrl}`);
  for (const d of DEVICES) {
    await audit(browser, d);
  }
  await browser.close();
  console.log("\n✓ done →", screensDir);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
