import { test, expect } from '@playwright/test';

test.describe('Watch Page', () => {
  test('should load watch page', async ({ page }) => {
    await page.goto('/watch/demo');
    
    // Should have video player
    const videoPlayer = page.locator('video, [class*="video-player"], [class*="video-js"]').first();
    await expect(videoPlayer).toBeVisible({ timeout: 10000 });
  });

  test('should display video information', async ({ page }) => {
    await page.goto('/watch/demo');
    
    // Should have video title
    const title = page.locator('h1, [class*="video-title"]').first();
    await expect(title).toBeVisible({ timeout: 5000 });
  });

  test('should have subscribe button', async ({ page }) => {
    await page.goto('/watch/demo');
    
    const subscribeButton = page.getByRole('button', { name: /subscribe/i });
    await expect(subscribeButton).toBeVisible({ timeout: 5000 });
  });

  test('should play placeholder video', async ({ page }) => {
    await page.goto('/watch/demo');
    
    // Find play button
    const playButton = page.getByRole('button', { name: /play/i }).first();
    
    if (await playButton.isVisible({ timeout: 5000 })) {
      await playButton.click();
      
      // Video should start playing (check for playing state)
      await page.waitForTimeout(1000);
    }
  });

  test('should display related videos', async ({ page }) => {
    await page.goto('/watch/demo');
    
    // Scroll to related videos section
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
    
    // Should have related videos
    const relatedVideos = page.locator('[class*="recommendation"], [class*="related"]').first();
    await expect(relatedVideos).toBeVisible({ timeout: 10000 });
  });
});





