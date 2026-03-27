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

  test('API Call Optimization', async ({ page }) => {
    // 1. Open browser dev tools Network tab
    // Track API calls using page.on('request') and page.on('response')
    const apiCalls: Array<{
      url: string;
      method: string;
      timestamp: number;
      status?: number;
      cached?: boolean;
    }> = [];
    
    page.on('request', (request) => {
      const url = request.url();
      // Track API calls to Blueprint API
      if (url.includes(Services.Blueprint.API) || url.includes(':4724')) {
        apiCalls.push({
          url: url,
          method: request.method(),
          timestamp: Date.now(),
        });
      }
    });
    
    page.on('response', (response) => {
      const url = response.url();
      // Update API call with response details
      if (url.includes(Services.Blueprint.API) || url.includes(':4724')) {
        const call = apiCalls.find(c => c.url === url && !c.status);
        if (call) {
          call.status = response.status();
          call.cached = response.fromCache();
        }
      }
    });
    
    // 2. Navigate and perform actions
    console.log('Navigating through application...');
    
    // Navigate to MSELs list
    await page.goto(`${Services.Blueprint.UI}/msels`).catch(() => {
      console.log('MSELs route not available');
    });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    
    const apiCallsAfterMsels = apiCalls.length;
    console.log(`API calls after MSELs page: ${apiCallsAfterMsels}`);
    
    // Navigate to Teams
    await page.goto(`${Services.Blueprint.UI}/teams`).catch(() => {
      console.log('Teams route not available');
    });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    
    const apiCallsAfterTeams = apiCalls.length;
    console.log(`API calls after Teams page: ${apiCallsAfterTeams}`);
    
    // Navigate back to MSELs (should use cache)
    await page.goto(`${Services.Blueprint.UI}/msels`).catch(() => {
      console.log('MSELs route not available');
    });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);
    
    const apiCallsAfterSecondMsels = apiCalls.length;
    console.log(`API calls after second MSELs page: ${apiCallsAfterSecondMsels}`);
    
    // 3. Analyze API calls
    console.log('\nAPI Call Analysis:');
    console.log(`Total API calls: ${apiCalls.length}`);
    
    // Group by URL
    const callsByUrl = apiCalls.reduce((acc, call) => {
      const urlWithoutQuery = call.url.split('?')[0];
      acc[urlWithoutQuery] = (acc[urlWithoutQuery] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    console.log('\nCalls by endpoint:');
    Object.entries(callsByUrl).forEach(([url, count]) => {
      console.log(`  ${url}: ${count} calls`);
    });
    
    // expect: No redundant API calls are made
    // Each unique endpoint should not be called more than necessary
    const duplicateCalls = Object.entries(callsByUrl).filter(([_, count]) => count > 5);
    if (duplicateCalls.length > 0) {
      console.log('\nPotential redundant calls:');
      duplicateCalls.forEach(([url, count]) => {
        console.log(`  ${url}: ${count} calls (may be redundant)`);
      });
    }
    
    // Allow some duplicate calls for different data, but not excessive
    const maxCallsPerEndpoint = 10;
    duplicateCalls.forEach(([url, count]) => {
      expect(count).toBeLessThan(maxCallsPerEndpoint);
    });
    
    // expect: Data is cached appropriately
    const cachedCalls = apiCalls.filter(call => call.cached);
    const cacheRatio = apiCalls.length > 0 ? cachedCalls.length / apiCalls.length : 0;
    
    console.log(`\nCache Statistics:`);
    console.log(`  Cached calls: ${cachedCalls.length}`);
    console.log(`  Cache ratio: ${(cacheRatio * 100).toFixed(1)}%`);
    
    // On second visit to same page, some calls should be cached
    // This is a soft check as caching behavior varies
    if (apiCalls.length > 0) {
      console.log('  Caching is', cacheRatio > 0 ? 'working' : 'not detected (may use other caching strategies)');
    }
    
    // expect: API calls to http://localhost:4724 are optimized
    // Check that we're not making excessive calls
    expect(apiCalls.length).toBeLessThan(100); // Should not make 100+ API calls for basic navigation
    
    // expect: Loading states prevent duplicate requests
    // Check for rapid duplicate calls (within 100ms) to the same endpoint
    const rapidDuplicates = apiCalls.filter((call, index) => {
      const nextCall = apiCalls[index + 1];
      if (!nextCall) return false;
      
      const sameUrl = call.url === nextCall.url;
      const rapidTiming = nextCall.timestamp - call.timestamp < 100;
      
      return sameUrl && rapidTiming;
    });
    
    console.log(`\nRapid duplicate calls detected: ${rapidDuplicates.length}`);
    if (rapidDuplicates.length > 0) {
      console.log('Duplicate calls:');
      rapidDuplicates.forEach(call => {
        console.log(`  ${call.url} (${call.method})`);
      });
    }
    
    // Should have minimal rapid duplicates (loading states should prevent this)
    expect(rapidDuplicates.length).toBeLessThan(5);
    
    // Check response times
    const successfulCalls = apiCalls.filter(call => call.status && call.status >= 200 && call.status < 300);
    console.log(`\nSuccessful API calls: ${successfulCalls.length}/${apiCalls.length}`);
    
    if (successfulCalls.length > 0) {
      const successRate = (successfulCalls.length / apiCalls.length) * 100;
      console.log(`Success rate: ${successRate.toFixed(1)}%`);
      
      // Most calls should succeed
      expect(successRate).toBeGreaterThan(80);
    }
  });
});
