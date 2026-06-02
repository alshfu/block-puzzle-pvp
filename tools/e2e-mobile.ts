/**
 * E2E mobile viewport audit.
 *
 * Запускает headless Chromium, прогоняет приложение через viewport-ы
 * флагманов iPhone и Samsung Galaxy S за 2015–2024, делает скриншоты
 * ключевых экранов. Внутри каждого устройства — 3 варианта высоты,
 * имитирующих реальный браузерный chrome:
 *   - full: полный экран (как мокап).
 *   - urlbar: минус 80px (URL bar сверху виден, toolbar спрятан).
 *   - urlbar-toolbar: минус 150px (URL bar + bottom toolbar одновременно).
 *
 * Это позволяет видеть worst-case: реальный Mobile Safari/Chrome
 * НИКОГДА не отдаёт игре всю заданную dvh-высоту.
 *
 * Использование:
 *   npm run dev (в отдельном терминале или в фоне)
 *   npx tsx tools/e2e-mobile.ts http://localhost:5175/
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
}

interface ChromeVariant {
  suffix: string;
  /** Сколько px съедает браузерный chrome (URL bar + toolbar). */
  overhead: number;
}

const CHROME_VARIANTS: ChromeVariant[] = [
  { suffix: "full", overhead: 0 },
  { suffix: "urlbar", overhead: 80 },
  { suffix: "tight", overhead: 150 },
];

const DEVICES: Device[] = [
  { name: "iphone-6s", year: 2015, width: 375, height: 667, dpr: 2 },
  { name: "galaxy-s6", year: 2015, width: 360, height: 640, dpr: 4 },
  { name: "iphone-7", year: 2016, width: 375, height: 667, dpr: 2 },
  { name: "galaxy-s7", year: 2016, width: 360, height: 640, dpr: 4 },
  { name: "iphone-x", year: 2017, width: 375, height: 812, dpr: 3 },
  { name: "galaxy-s8", year: 2017, width: 360, height: 740, dpr: 3 },
  { name: "iphone-xs", year: 2018, width: 375, height: 812, dpr: 3 },
  { name: "galaxy-s9", year: 2018, width: 360, height: 740, dpr: 3 },
  { name: "iphone-11-pro", year: 2019, width: 375, height: 812, dpr: 3 },
  { name: "galaxy-s10", year: 2019, width: 360, height: 760, dpr: 3 },
  { name: "iphone-12-pro", year: 2020, width: 390, height: 844, dpr: 3 },
  { name: "galaxy-s20", year: 2020, width: 360, height: 800, dpr: 3 },
  { name: "iphone-13-pro", year: 2021, width: 390, height: 844, dpr: 3 },
  { name: "galaxy-s21", year: 2021, width: 360, height: 800, dpr: 3 },
  { name: "iphone-14-pro", year: 2022, width: 393, height: 852, dpr: 3 },
  { name: "galaxy-s22", year: 2022, width: 360, height: 780, dpr: 3 },
  { name: "iphone-15-pro-max", year: 2023, width: 430, height: 932, dpr: 3 },
  { name: "galaxy-s23", year: 2023, width: 360, height: 780, dpr: 3 },
  { name: "iphone-16-pro-max", year: 2024, width: 440, height: 956, dpr: 3 },
  { name: "galaxy-s24", year: 2024, width: 360, height: 780, dpr: 3 },
];

const baseUrl = process.argv[2] ?? "http://localhost:5175/";
const screensDir = join(process.cwd(), "tools", "screens");

mkdirSync(screensDir, { recursive: true });

async function snap(page: Page, name: string): Promise<void> {
  await page.screenshot({ path: join(screensDir, `${name}.png`), fullPage: false });
  console.log("  →", name);
}

async function settle(page: Page, ms = 300): Promise<void> {
  await page.waitForTimeout(ms);
}

async function flow(page: Page, tag: string): Promise<void> {
  await page.goto(baseUrl, { waitUntil: "networkidle", timeout: 15000 });
  await settle(page, 400);
  await snap(page, `${tag}-01-menu`);

  const heroBtn = page.locator(".hero-btn").first();
  if (await heroBtn.isVisible().catch(() => false)) {
    await heroBtn.click();
    await settle(page);
    await snap(page, `${tag}-02-menu-modes`);
  }

  const onlineMode = page.locator(".mode-btn", { hasText: "Онлайн" }).first();
  if (await onlineMode.isVisible().catch(() => false)) {
    await onlineMode.click();
    await settle(page, 500);
    await snap(page, `${tag}-03-online-setup`);
    const back = page.locator(".back-link").first();
    if (await back.isVisible().catch(() => false)) {
      await back.click();
      await settle(page);
    }
    if (await heroBtn.isVisible().catch(() => false)) {
      await heroBtn.click();
      await settle(page);
    }
  }

  const vsBot = page.locator(".mode-btn", { hasText: "С ботом" }).first();
  if (await vsBot.isVisible().catch(() => false)) {
    await vsBot.click();
    await settle(page);
    await snap(page, `${tag}-04-setup`);
    const start = page.locator(".start-btn").first();
    if (await start.isVisible().catch(() => false)) {
      await start.click();
      await settle(page, 700);
      await snap(page, `${tag}-05-game`);

      // Дополнительная диагностика: считаем сколько пикселей контента не помещается.
      const metrics = await page.evaluate(() => {
        const root = document.querySelector(".game-screen") as HTMLElement | null;
        const board = document.querySelector(".game-screen .board") as HTMLElement | null;
        const phone = document.querySelector(".phone") as HTMLElement | null;
        return {
          viewportHeight: window.innerHeight,
          viewportWidth: window.innerWidth,
          phoneScrollHeight: phone?.scrollHeight ?? null,
          phoneClientHeight: phone?.clientHeight ?? null,
          gameScrollHeight: root?.scrollHeight ?? null,
          gameClientHeight: root?.clientHeight ?? null,
          gameOverflow: root ? Math.max(0, root.scrollHeight - root.clientHeight) : null,
          boardRect: board?.getBoundingClientRect().toJSON() ?? null,
        };
      });
      console.log(`    metrics: vp=${metrics.viewportWidth}×${metrics.viewportHeight}, board=${metrics.boardRect ? Math.round(metrics.boardRect.width) + "×" + Math.round(metrics.boardRect.height) : "n/a"}, gameOverflow=${metrics.gameOverflow}px`);
    }
  }
}

async function audit(browser: Browser, device: Device, variant: ChromeVariant): Promise<void> {
  const realHeight = Math.max(360, device.height - variant.overhead);
  const tag = `${device.year}-${device.name}-${variant.suffix}`;
  console.log(`\n● ${tag} ${device.width}×${realHeight} (overhead ${variant.overhead}px)`);
  const ctx = await browser.newContext({
    viewport: { width: device.width, height: realHeight },
    deviceScaleFactor: device.dpr ?? 2,
    isMobile: true,
    hasTouch: true,
    userAgent:
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  });
  const page = await ctx.newPage();
  page.on("console", (m) => {
    if (m.type() === "error") console.log(`    [error] ${m.text()}`);
  });
  try {
    await flow(page, tag);
  } catch (e) {
    console.log(`    ! error: ${e}`);
  } finally {
    await ctx.close();
  }
}

async function main(): Promise<void> {
  const browser = await chromium.launch({ headless: true });
  console.log(`base url: ${baseUrl}`);
  for (const d of DEVICES) {
    for (const v of CHROME_VARIANTS) {
      await audit(browser, d, v);
    }
  }
  await browser.close();
  console.log(`\n✓ done → ${screensDir}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
