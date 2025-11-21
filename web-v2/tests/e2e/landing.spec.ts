import { test, expect } from '@playwright/test';

test.describe('Landing Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should load landing page', async ({ page }) => {
    await expect(page).toHaveTitle(/MyChannel/);
  });

  test('should display header with logo and navigation', async ({ page }) => {
    const header = page.locator('header');
    await expect(header).toBeVisible();
    
    const logo = page.getByRole('link', { name: /MyChannel/i });
    await expect(logo).toBeVisible();
  });

  test('should have search functionality', async ({ page }) => {
    const searchInput = page.getByRole('searchbox', { name: /search videos/i });
    await expect(searchInput).toBeVisible();
    
    await searchInput.fill('test query');
    await searchInput.press('Enter');
    
    // Should navigate to search page
    await expect(page).toHaveURL(/\/search/);
  });

  test('should display video cards', async ({ page }) => {
    // Wait for video cards to load
    const videoCards = page.locator('[class*="video-card"]');
    await expect(videoCards.first()).toBeVisible({ timeout: 10000 });
  });

  test('should navigate to watch page when clicking video', async ({ page }) => {
    // Wait for video cards
    const firstVideo = page.locator('[class*="video-card"]').first();
    await expect(firstVideo).toBeVisible({ timeout: 10000 });
    
    await firstVideo.click();
    
    // Should navigate to watch page
    await expect(page).toHaveURL(/\/watch\//);
  });

  test('should be keyboard navigable', async ({ page }) => {
    // Test '/' key focuses search
    await page.keyboard.press('/');
    const searchInput = page.getByRole('searchbox');
    await expect(searchInput).toBeFocused();
    
    // Test Escape closes menus
    await page.keyboard.press('Escape');
    await expect(searchInput).not.toBeFocused();
  });

  test('should be responsive on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    
    const header = page.locator('header');
    await expect(header).toBeVisible();
    
    // Mobile should show hamburger menu
    const menuButton = page.getByRole('button', { name: /toggle sidebar/i });
    await expect(menuButton).toBeVisible();
  });
});



