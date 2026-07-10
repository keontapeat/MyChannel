import { test, expect } from '@playwright/test';

test.describe('VS Match Create', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/medals/create-match');
  });

  test('should load create-match page', async ({ page }) => {
    await expect(page).toHaveURL(/\/medals\/create-match/);
    await expect(page.getByRole('heading', { name: /Create VS Match/i })).toBeVisible();
  });

  test('should display wager amount input and medal division', async ({ page }) => {
    const wagerInput = page.locator('input[type="number"]');
    await expect(wagerInput).toBeVisible();
    await expect(wagerInput).toHaveValue('500');

    await expect(page.getByText(/Gold Medal|Silver Medal|Bronze Medal/i)).toBeVisible();
  });

  test('should show compliance preflight banner', async ({ page }) => {
    await expect(page.getByLabel(/Compliance status/i)).toBeVisible();
    await expect(page.getByText(/Compliance preflight/i)).toBeVisible();
    await expect(page.getByText(/KYC/i)).toBeVisible();
    await expect(page.getByText(/Daily limit/i)).toBeVisible();
  });

  test('should disable create button when preflight fails', async ({ page }) => {
    const createButton = page.getByRole('button', { name: /Create Match/i });
    await expect(createButton).toBeDisabled();
  });

  test('should allow category selection', async ({ page }) => {
    const gamingButton = page.getByRole('button', { name: /Gaming/i });
    await expect(gamingButton).toBeVisible();
    await gamingButton.click();
    await expect(gamingButton).toHaveClass(/from-blue-600/);
  });

  test('should navigate back to medals', async ({ page }) => {
    const backLink = page.locator('header a[href="/medals"]');
    await expect(backLink).toBeVisible();
    await backLink.click();
    await expect(page).toHaveURL(/\/medals/);
  });
});
