// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Authentication and Authorization', () => {
  test('Access Token Expiration Redirect', async ({ page }) => {
    // 1. Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Successfully authenticated
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible();
    
    // 2. Wait for token to expire or manually invalidate the token
    // Manually invalidate the token by modifying it in local storage
    await page.evaluate(() => {
      const storageKey = 'oidc.user:https://localhost:8443/realms/crucible:blueprint-ui';
      const userData = localStorage.getItem(storageKey);
      if (userData) {
        const parsed = JSON.parse(userData);
        // Set the token to an invalid value
        parsed.access_token = 'invalid_token';
        // Set expiration to past time
        parsed.expires_at = Math.floor(Date.now() / 1000) - 1000;
        localStorage.setItem(storageKey, JSON.stringify(parsed));
      }
    });
    
    // expect: Token expiration occurs
    const tokenExpired = await page.evaluate(() => {
      const storageKey = 'oidc.user:https://localhost:8443/realms/crucible:blueprint-ui';
      const userData = localStorage.getItem(storageKey);
      if (userData) {
        const parsed = JSON.parse(userData);
        const now = Math.floor(Date.now() / 1000);
        return parsed.expires_at < now;
      }
      return false;
    });
    expect(tokenExpired).toBe(true);
    
    // 3. Attempt to perform an authenticated action
    // Try to navigate to a protected section or make an API call
    await page.reload();
    
    // expect: The application detects expired token (useAccessTokenExpirationRedirect is enabled)
    // expect: User is redirected to Keycloak login page
    await page.waitForTimeout(2000); // Allow time for token validation
    
    // The app should detect the expired token and redirect
    await expect(page).toHaveURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // expect: User must re-authenticate to continue
    const usernameField = page.locator('input[name="username"]');
    const passwordField = page.locator('input[name="password"]');
    await expect(usernameField).toBeVisible();
    await expect(passwordField).toBeVisible();
    
    // Verify the Blueprint content is not accessible
    const blueprintContent = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(blueprintContent).not.toBeVisible();
  });
});
