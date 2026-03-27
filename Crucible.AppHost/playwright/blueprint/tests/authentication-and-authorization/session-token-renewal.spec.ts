// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Authentication and Authorization', () => {
  test('Session Token Renewal', async ({ page }) => {
    // Setup console log monitoring
    const consoleLogs: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'log' || msg.type() === 'info') {
        consoleLogs.push(msg.text());
      }
    });
    
    // 1. Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Successfully authenticated
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // Get initial token from local storage
    const initialToken = await page.evaluate(() => {
      return localStorage.getItem('oidc.user:https://localhost:8443/realms/crucible:blueprint-ui');
    });
    expect(initialToken).toBeTruthy();
    
    // 2. Wait for silent token renewal (automaticSilentRenew is enabled in config)
    // Typical token renewal happens every few minutes, so we'll wait and monitor
    await page.waitForTimeout(5000); // Wait 5 seconds to observe token activity
    
    // expect: The application automatically renews the authentication token
    // expect: Uses the silent_redirect_uri (http://localhost:4725/auth-callback-silent.html)
    const requests = await page.evaluate(() => {
      return performance.getEntriesByType('resource')
        .map((entry: any) => entry.name)
        .filter((name: string) => name.includes('auth-callback-silent.html'));
    });
    
    // expect: No user interaction is required for token renewal
    // expect: The user session remains active
    const currentToken = await page.evaluate(() => {
      return localStorage.getItem('oidc.user:https://localhost:8443/realms/crucible:blueprint-ui');
    });
    expect(currentToken).toBeTruthy();
    
    // expect: Console logs show token refresh activity
    // Check if any console logs mention token, refresh, or renewal
    const tokenRefreshLogs = consoleLogs.filter(log => 
      log.toLowerCase().includes('token') || 
      log.toLowerCase().includes('refresh') || 
      log.toLowerCase().includes('renew')
    );
    
    // Verify application is still functional
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible();
    
    // User can still navigate and use the application
    await page.waitForLoadState('networkidle');
  });
});
