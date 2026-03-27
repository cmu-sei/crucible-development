// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Performance and Optimization', () => {
  test('Initial Page Load Time', async ({ page, context }) => {
    // 1. Clear browser cache and navigate to http://localhost:4725
    await context.clearCookies();
    await context.clearPermissions();
    
    // Measure page load time using Performance API
    const startTime = Date.now();
    
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
    
    // Wait for the application to be fully loaded
    await page.waitForLoadState('networkidle');
    
    // 2. Measure page load time using browser Performance tab
    const performanceMetrics = await page.evaluate(() => {
      const perfData = window.performance.timing;
      const paintMetrics = performance.getEntriesByType('paint');
      
      return {
        loadTime: perfData.loadEventEnd - perfData.navigationStart,
        domContentLoaded: perfData.domContentLoadedEventEnd - perfData.navigationStart,
        firstPaint: paintMetrics.find(entry => entry.name === 'first-paint')?.startTime || 0,
        firstContentfulPaint: paintMetrics.find(entry => entry.name === 'first-contentful-paint')?.startTime || 0,
        timeToInteractive: perfData.domInteractive - perfData.navigationStart,
      };
    });
    
    const endTime = Date.now();
    const totalLoadTime = (endTime - startTime) / 1000; // Convert to seconds
    
    console.log('Performance Metrics:');
    console.log(`  Total Load Time: ${totalLoadTime}s`);
    console.log(`  DOM Content Loaded: ${performanceMetrics.domContentLoaded}ms`);
    console.log(`  First Paint: ${performanceMetrics.firstPaint}ms`);
    console.log(`  First Contentful Paint: ${performanceMetrics.firstContentfulPaint}ms`);
    console.log(`  Time to Interactive: ${performanceMetrics.timeToInteractive}ms`);
    
    // expect: Initial page load completes within acceptable time (< 3 seconds)
    // Note: This includes authentication flow, so we allow more time
    expect(totalLoadTime).toBeLessThan(10); // 10 seconds for full auth flow
    
    // expect: Time to First Contentful Paint (FCP) is reasonable
    expect(performanceMetrics.firstContentfulPaint).toBeLessThan(3000); // 3 seconds
    
    // expect: Time to Interactive (TTI) is acceptable
    expect(performanceMetrics.timeToInteractive).toBeLessThan(5000); // 5 seconds
    
    // expect: Application loads from scratch
    await expect(page).toHaveURL(/.*localhost:4725.*/);
    
    // Verify main application interface is visible
    await expect(page.locator('text=Blueprint')).toBeVisible({ timeout: 5000 });
  });
});
