// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Authentication and Authorization', () => {
  test('User Logout Flow', async ({ page }) => {
    // 1. Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Successfully authenticated and viewing the home page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible();
    
    // 2. Click on the user menu in the topbar
    const userMenu = page.locator('[class*="user-menu"], [class*="user-profile"], button:has-text("admin")').first();
    await userMenu.click();
    
    // expect: A dropdown menu appears with logout option
    const logoutOption = page.locator('text=Logout, text=Log Out, text=Sign Out').first();
    await expect(logoutOption).toBeVisible({ timeout: 3000 });
    
    // 3. Click 'Logout' option
    await logoutOption.click();
    
    // expect: The user is logged out
    // expect: Authentication tokens are cleared from local storage
    await page.waitForTimeout(1000); // Allow time for logout to complete
    
    const localStorageKeys = await page.evaluate(() => {
      return Object.keys(localStorage).filter(key => 
        key.includes('auth') || 
        key.includes('token') || 
        key.includes('oidc')
      );
    });
    expect(localStorageKeys.length).toBe(0);
    
    // expect: The user is redirected to the Keycloak logout page or login page
    await expect(page).toHaveURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // Verify user cannot access Blueprint without re-authenticating
    await page.goto(Services.Blueprint.UI);
    await expect(page).toHaveURL(/.*localhost:8443.*/, { timeout: 10000 });
  });
});
