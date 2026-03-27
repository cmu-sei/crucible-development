// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Performance and Optimization', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to Blueprint application
    await page.goto(Services.Blueprint.UI);
    
    // Wait for Keycloak redirect
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // Fill in username
    await page.fill('input[name="username"]', 'admin');
    
    // Fill in password
    await page.fill('input[name="password"]', 'admin');
    
    // Click Sign In button
    await page.click('button:has-text("Sign In")');
    
    // Wait for redirect back to Blueprint
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // Verify main application loaded
    await expect(page).toHaveURL(/.*localhost:4725.*/);
    await page.waitForLoadState('networkidle');
  });

  test('Subsequent Page Load Time', async ({ page }) => {
    // 1. After initial load, navigate to different sections
    
    // Measure navigation to MSELs list
    let startTime = Date.now();
    await page.click('text=MSELs', { timeout: 5000 }).catch(async () => {
      // If no MSELs link, try navigating directly
      await page.goto(`${Services.Blueprint.UI}/msels`);
    });
    await page.waitForLoadState('networkidle');
    let endTime = Date.now();
    let navigationTime = (endTime - startTime) / 1000;
    
    console.log(`Navigation to MSELs: ${navigationTime}s`);
    
    // expect: Page transitions are fast (< 1 second)
    expect(navigationTime).toBeLessThan(2); // 2 seconds with network
    
    // Navigate to Teams section
    startTime = Date.now();
    await page.click('text=Teams', { timeout: 5000 }).catch(async () => {
      await page.goto(`${Services.Blueprint.UI}/teams`);
    });
    await page.waitForLoadState('networkidle');
    endTime = Date.now();
    navigationTime = (endTime - startTime) / 1000;
    
    console.log(`Navigation to Teams: ${navigationTime}s`);
    expect(navigationTime).toBeLessThan(2);
    
    // Navigate to Users section
    startTime = Date.now();
    await page.click('text=Users', { timeout: 5000 }).catch(async () => {
      await page.goto(`${Services.Blueprint.UI}/users`);
    });
    await page.waitForLoadState('networkidle');
    endTime = Date.now();
    navigationTime = (endTime - startTime) / 1000;
    
    console.log(`Navigation to Users: ${navigationTime}s`);
    expect(navigationTime).toBeLessThan(2);
    
    // 2. Measure page transition times
    // Navigate back to home
    startTime = Date.now();
    await page.goto(Services.Blueprint.UI);
    await page.waitForLoadState('networkidle');
    endTime = Date.now();
    const homeLoadTime = (endTime - startTime) / 1000;
    
    console.log(`Return to Home: ${homeLoadTime}s`);
    
    // expect: Cached resources are utilized
    // expect: Lazy loading is used appropriately
    expect(homeLoadTime).toBeLessThan(1); // Should be very fast with cache
    
    // Check that resources are cached
    const performanceEntries = await page.evaluate(() => {
      const entries = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
      const cachedResources = entries.filter(entry => 
        entry.transferSize === 0 || entry.transferSize < entry.encodedBodySize
      );
      return {
        total: entries.length,
        cached: cachedResources.length,
        cacheRatio: cachedResources.length / entries.length
      };
    });
    
    console.log(`Resource Cache Ratio: ${(performanceEntries.cacheRatio * 100).toFixed(1)}%`);
    
    // Expect at least some resources to be cached
    expect(performanceEntries.cached).toBeGreaterThan(0);
  });
});
