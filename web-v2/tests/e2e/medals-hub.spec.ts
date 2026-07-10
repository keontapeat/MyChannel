import { test, expect } from '@playwright/test';

test.describe('Medals Championship Hub', () => {
  test('should load medals page', async ({ page }) => {
    await page.goto('/medals');
    await expect(page).toHaveURL(/\/medals/);
    await expect(page.getByRole('heading', { name: /Championship Hub/i })).toBeVisible();
  });

  test('should show medal divisions and create match CTA', async ({ page }) => {
    await page.goto('/medals');
    await expect(page.getByText(/Medal Divisions/i)).toBeVisible();
    await expect(page.getByRole('link', { name: /Create Championship Match/i })).toBeVisible();
  });

  test('should show empty state or rankings tab', async ({ page }) => {
    await page.goto('/medals');
    await expect(page.getByRole('button', { name: /Rankings/i })).toBeVisible();
    const emptyOrLoading = page.getByText(/No live rankings yet|Loading rankings/i);
    await expect(emptyOrLoading.or(page.locator('section').filter({ hasText: 'Top 15 Rankings' }))).toBeVisible({
      timeout: 10_000,
    });
  });
});
