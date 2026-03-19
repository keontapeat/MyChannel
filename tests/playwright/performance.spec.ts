/**
 * Playwright Performance Tests
 * Automated performance regression testing
 */

import { test, expect } from '@playwright/test';

test.describe('Performance Tests', () => {
  test('Home page loads in <2 seconds', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    console.log(`📊 Home page load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(2000);
  });

  test('Video player starts in <500ms', async ({ page }) => {
    await page.goto('/watch?v=test-video-id');
    
    const startTime = Date.now();
    await page.click('[data-testid="play-button"]');
    
    // Wait for video to start playing
    await page.waitForSelector('video[data-playing="true"]', { timeout: 1000 });
    
    const playbackStartTime = Date.now() - startTime;
    
    console.log(`📺 Video playback start time: ${playbackStartTime}ms`);
    expect(playbackStartTime).toBeLessThan(500);
  });

  test('Infinite scroll maintains 60fps', async ({ page }) => {
    await page.goto('/shorts');
    
    // Start FPS monitoring
    const fpsData: number[] = [];
    
    await page.evaluate(() => {
      let lastTime = performance.now();
      let frames = 0;
      
      function measureFPS() {
        const now = performance.now();
        frames++;
        
        if (now >= lastTime + 1000) {
          const fps = Math.round((frames * 1000) / (now - lastTime));
          (window as any).__fpsData = (window as any).__fpsData || [];
          (window as any).__fpsData.push(fps);
          
          frames = 0;
          lastTime = now;
        }
        
        requestAnimationFrame(measureFPS);
      }
      
      measureFPS();
    });
    
    // Scroll through 10 videos
    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('ArrowDown');
      await page.waitForTimeout(1000);
    }
    
    // Get FPS data
    const fps = await page.evaluate(() => (window as any).__fpsData);
    const avgFPS = fps.reduce((a: number, b: number) => a + b, 0) / fps.length;
    
    console.log(`🎬 Average FPS during scroll: ${avgFPS}`);
    expect(avgFPS).toBeGreaterThan(58); // Allow 2fps tolerance
  });

  test('Search results appear in <200ms', async ({ page }) => {
    await page.goto('/');
    
    const searchInput = page.locator('[data-testid="search-input"]');
    
    const startTime = Date.now();
    await searchInput.fill('test query');
    
    // Wait for results
    await page.waitForSelector('[data-testid="search-results"]');
    
    const searchTime = Date.now() - startTime;
    
    console.log(`🔍 Search results time: ${searchTime}ms`);
    expect(searchTime).toBeLessThan(200);
  });

  test('Image loading is optimized', async ({ page }) => {
    await page.goto('/');
    
    // Get all images
    const images = await page.locator('img').all();
    
    let loadedCount = 0;
    let totalLoadTime = 0;
    
    for (const img of images) {
      const src = await img.getAttribute('src');
      if (!src) continue;
      
      const startTime = Date.now();
      await img.waitFor({ state: 'visible', timeout: 5000 });
      const loadTime = Date.now() - startTime;
      
      totalLoadTime += loadTime;
      loadedCount++;
    }
    
    const avgLoadTime = totalLoadTime / loadedCount;
    
    console.log(`🖼️ Average image load time: ${avgLoadTime}ms`);
    expect(avgLoadTime).toBeLessThan(200);
  });

  test('Memory usage stays under 200MB', async ({ page }) => {
    await page.goto('/');
    
    // Navigate through app
    await page.click('[href="/shorts"]');
    await page.waitForTimeout(2000);
    
    await page.click('[href="/subscriptions"]');
    await page.waitForTimeout(2000);
    
    // Measure memory
    const metrics = await page.evaluate(() => {
      if ('memory' in performance) {
        return (performance as any).memory.usedJSHeapSize / 1024 / 1024;
      }
      return 0;
    });
    
    console.log(`🧠 Memory usage: ${metrics}MB`);
    expect(metrics).toBeLessThan(200);
  });

  test('API response times are <100ms', async ({ page }) => {
    const apiTimes: number[] = [];
    
    page.on('response', response => {
      if (response.url().includes('/api/')) {
        const timing = response.timing();
        if (timing) {
          apiTimes.push(timing.responseEnd);
        }
      }
    });
    
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const avgApiTime = apiTimes.reduce((a, b) => a + b, 0) / apiTimes.length;
    
    console.log(`⚡ Average API response time: ${avgApiTime}ms`);
    expect(avgApiTime).toBeLessThan(100);
  });
});

test.describe('Core Web Vitals', () => {
  test('LCP is <2.5 seconds', async ({ page }) => {
    await page.goto('/');
    
    const lcp = await page.evaluate(() => {
      return new Promise((resolve) => {
        new PerformanceObserver((list) => {
          const entries = list.getEntries();
          const lastEntry = entries[entries.length - 1];
          resolve(lastEntry.renderTime || lastEntry.loadTime);
        }).observe({ entryTypes: ['largest-contentful-paint'] });
      });
    });
    
    console.log(`📊 LCP: ${lcp}ms`);
    expect(lcp).toBeLessThan(2500);
  });

  test('FID is <100ms', async ({ page }) => {
    await page.goto('/');
    
    const fid = await page.evaluate(() => {
      return new Promise((resolve) => {
        new PerformanceObserver((list) => {
          const entries = list.getEntries();
          resolve(entries[0].processingStart - entries[0].startTime);
        }).observe({ entryTypes: ['first-input'] });
        
        // Simulate user interaction
        document.body.click();
      });
    });
    
    console.log(`📊 FID: ${fid}ms`);
    expect(fid).toBeLessThan(100);
  });

  test('CLS is <0.1', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const cls = await page.evaluate(() => {
      return new Promise((resolve) => {
        let clsValue = 0;
        
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            if (!(entry as any).hadRecentInput) {
              clsValue += (entry as any).value;
            }
          }
          resolve(clsValue);
        }).observe({ entryTypes: ['layout-shift'] });
        
        setTimeout(() => resolve(clsValue), 5000);
      });
    });
    
    console.log(`📊 CLS: ${cls}`);
    expect(cls).toBeLessThan(0.1);
  });
});
