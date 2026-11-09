import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
async function go(page: Page, path: string) {
  await page.goto(path);
  await page.locator('html[data-hydrated=true]').waitFor();
}
import AxeBuilder from '@axe-core/playwright';
import { pages } from '../../src/content/pages';
test('complete homepage and footer destinations', async ({ page, request }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await go(page, '/');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(
    'Money that finallyexplains itself.'
  );
  for (const href of Object.keys(pages)) {
    const response = await request.get(href);
    expect(response.status(), href).toBe(200);
    expect(await response.text(), href).toContain(
      pages[href].title.replaceAll('&', '&amp;')
    );
  }
  const links = await page
    .locator('footer a')
    .evaluateAll((elements) => elements.map((e) => e.getAttribute('href')));
  expect(links.every((href) => href && href !== '#')).toBe(true);
  expect((await request.get('/something-that-does-not-exist')).status()).toBe(
    404
  );
  expect(
    (await request.get('/privacy-policy', { maxRedirects: 0 })).status()
  ).toBe(301);
  expect(errors).toEqual([]);
});
test('waitlist platform, persistence receipt, errors, and focus restoration', async ({
  page,
}) => {
  await go(page, '/');
  await page.locator('html[data-hydrated=true]').waitFor();
  const trigger = page.locator('[data-store-platform=ios]').first();
  await trigger.click();
  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('radio', { name: 'iPhone' })).toBeChecked();
  await dialog.getByLabel('Email address').fill('maya@example.test');
  await dialog.getByRole('checkbox').check();
  await page.route('**/api/waitlist', (route) =>
    route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'Please try again.' }),
    })
  );
  await dialog.getByRole('button', { name: 'Join the waitlist' }).click();
  await expect(dialog.getByRole('alert')).toContainText('Please try again.');
  await expect(dialog.getByLabel('Email address')).toHaveValue(
    'maya@example.test'
  );
  await page.route('**/api/waitlist', (route) =>
    route.fulfill({ json: { ok: true } })
  );
  await dialog.getByRole('button', { name: 'Join the waitlist' }).click();
  await expect(dialog.getByRole('status')).toContainText('You’re on the list');
  await page.keyboard.press('Escape');
  await expect(dialog).not.toBeVisible();
  await expect(trigger).toBeFocused();
});
test('mobile navigation closes by selection and Escape', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await go(page, '/');
  await page.locator('html[data-hydrated=true]').waitFor();
  const menu = page.getByRole('button', { name: 'Menu' });
  await menu.click();
  await expect(menu).toHaveAttribute('aria-expanded', 'true');
  await page
    .getByRole('navigation', { name: 'Mobile navigation' })
    .getByRole('link', { name: 'Voice', exact: true })
    .click();
  await expect(menu).toHaveAttribute('aria-expanded', 'false');
  await menu.click();
  await page.keyboard.press('Escape');
  await expect(menu).toBeFocused();
});
test('advice respects reduced motion and manual selection', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await go(page, '/');
  await page.locator('html[data-hydrated=true]').waitFor();
  await page.locator('#ai').scrollIntoViewIfNeeded();
  const first = page.locator('[data-aid=ai] .msg').first();
  await expect(first).toHaveAttribute('aria-hidden', 'false');
  await page.waitForTimeout(3200);
  await expect(first).toHaveAttribute('aria-hidden', 'false');
  await page.getByRole('button', { name: 'Show insight 2' }).click();
  await expect(first).toHaveAttribute('aria-hidden', 'true');
  await expect(page.locator('[data-aid=ai] .msg').nth(1)).toHaveAttribute(
    'aria-hidden',
    'false'
  );
});
test('contact category, retry ID, and receipt', async ({ page }) => {
  await go(page, '/delete-data');
  const ids: string[] = [];
  await page.route('**/api/contact', async (route) => {
    ids.push(route.request().postDataJSON().submissionId);
    await route.fulfill({
      status: ids.length === 1 ? 503 : 200,
      json: ids.length === 1 ? { message: 'Please try again.' } : { ok: true },
    });
  });
  await expect(page.getByLabel('What’s this about?')).toHaveValue('deletion');
  await page
    .locator('main')
    .getByLabel('Email address')
    .fill('maya@example.test');
  await page
    .getByLabel('Your message')
    .fill('Please remove my waitlist signup.');
  await page.getByRole('button', { name: 'Send inquiry' }).click();
  await expect(page.getByRole('alert')).toContainText('Please try again.');
  await page.getByRole('button', { name: 'Send inquiry' }).click();
  await expect(page.getByRole('status')).toContainText(
    'Thanks for getting in touch.'
  );
  expect(ids[0]).toBe(ids[1]);
});
test('homepage and forms pass accessibility rules', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  for (const path of ['/', '/waitlist', '/contact', '/help']) {
    await go(page, path);
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();
    expect(
      results.violations.map(
        (v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`
      ),
      path
    ).toEqual([]);
  }
});
test('responsive content has no document overflow', async ({ page }) => {
  for (const width of [320, 375, 390, 768, 834, 1024, 1280, 1440, 1920]) {
    await page.setViewportSize({ width, height: 900 });
    await go(page, '/');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth
      ),
      `width ${width}`
    ).toBe(true);
  }
});
test('help search returns useful results', async ({ page }) => {
  await go(page, '/help');
  await page.getByLabel('Search help').fill('subscription');
  await expect(page.getByRole('status')).toContainText('answer');
  await page.getByText('Does a reminder cancel a subscription?').click();
  await expect(
    page.getByText('No. A reminder helps you decide', { exact: false })
  ).toBeVisible();
});

test('content and store-link fallback remain usable without JavaScript', async ({
  browser,
  baseURL,
}) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  await page.goto(`${baseURL}/`);
  await expect(
    page.getByRole('heading', { name: 'Every subscription, before it renews.' })
  ).toBeVisible();
  await page.locator('[data-store-platform=android]').first().click();
  await expect(page).toHaveURL(/\/waitlist\?platform=android/);
  await expect(
    page.locator('main').getByRole('radio', { name: 'Android', exact: true })
  ).toBeChecked();
  await context.close();
});
test('a throttled signup keeps its values and explains retry timing', async ({
  page,
}) => {
  await go(page, '/waitlist');
  const form = page.locator('main').getByRole('form');
  await form.getByLabel('Email address').fill('maya@example.test');
  await form.getByRole('checkbox').check();
  await page.route('**/api/waitlist', (route) =>
    route.fulfill({ status: 429, headers: { 'Retry-After': '42' }, body: '' })
  );
  await form.getByRole('button', { name: 'Join the waitlist' }).click();
  await expect(form.getByRole('alert')).toContainText('42 seconds');
  await expect(form.getByLabel('Email address')).toHaveValue(
    'maya@example.test'
  );
});
test('layouts reflow at a 200% zoom-equivalent viewport', async ({
  browser,
  baseURL,
}) => {
  const context = await browser.newContext({
    viewport: { width: 720, height: 450 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  await page.goto(`${baseURL}/`);
  await page.locator('html[data-hydrated=true]').waitFor();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth
    )
  ).toBe(true);
  await page.getByRole('link', { name: 'Get the app', exact: true }).click();
  await expect(page.locator('#cta')).toBeInViewport();
  await context.close();
});
