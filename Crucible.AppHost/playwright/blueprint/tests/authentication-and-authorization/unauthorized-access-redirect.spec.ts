// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Authentication and Authorization', () => {
  test('Unauthorized Access Redirect', async ({ page }) => {
    // 1. Clear all browser cookies and local storage
    await page.context().clearCookies();
    await page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    
    // expect: All authentication tokens are removed
    const localStorageKeys = await page.evaluate(() => Object.keys(localStorage));
    expect(localStorageKeys.length).toBe(0);
    
    // 2. Navigate to http://localhost:4725
    await page.goto(Services.Blueprint.UI);
    
    // expect: The application redirects to the Keycloak login page
    await expect(page).toHaveURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // expect: No application content is displayed before authentication
    const blueprintContent = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(blueprintContent).not.toBeVisible();
    
    // Verify Keycloak login form is displayed
    const usernameField = page.locator('input[name="username"]');
    const passwordField = page.locator('input[name="password"]');
    await expect(usernameField).toBeVisible();
    await expect(passwordField).toBeVisible();
  });
});
