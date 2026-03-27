// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Authentication and Authorization', () => {
  test('User Login Flow', async ({ page }) => {
    // 1. Navigate to http://localhost:4725
    await page.goto(Services.Blueprint.UI);
    
    // expect: The application redirects to the Keycloak authentication page
    await expect(page).toHaveURL(/.*localhost:8443.*realms\/crucible/, { timeout: 10000 });
    
    // 2. Enter username 'admin' in the username field
    const usernameField = page.locator('input[name="username"]');
    await usernameField.fill('admin');
    
    // expect: The username field accepts input
    await expect(usernameField).toHaveValue('admin');
    
    // 3. Enter password 'admin' in the password field
    const passwordField = page.locator('input[name="password"]');
    await passwordField.fill('admin');
    
    // expect: The password field accepts input and masks the password
    await expect(passwordField).toHaveValue('admin');
    await expect(passwordField).toHaveAttribute('type', 'password');
    
    // 4. Click the 'Sign In' button
    await page.click('button:has-text("Sign In")');
    
    // expect: The application authenticates successfully
    // expect: The user is redirected back to http://localhost:4725
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // expect: The main application interface loads
    await page.waitForLoadState('networkidle');
    
    // expect: The topbar displays 'Blueprint - Collaborative MSEL Creation'
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible({ timeout: 5000 });
    
    // expect: The topbar background color is #2d69b4 with white text
    const topbar = page.locator('[class*="topbar"], [class*="top-bar"], [class*="header"]').first();
    const backgroundColor = await topbar.evaluate((el) => {
      return window.getComputedStyle(el).backgroundColor;
    });
    // RGB(45, 105, 180) = #2d69b4
    expect(backgroundColor).toMatch(/rgb\(45,\s*105,\s*180\)/);
    
    const textColor = await topbar.evaluate((el) => {
      return window.getComputedStyle(el).color;
    });
    // RGB(255, 255, 255) = #FFFFFF (white)
    expect(textColor).toMatch(/rgb\(255,\s*255,\s*255\)/);
    
    // expect: The username 'admin' is displayed in the topbar
    const usernameDisplay = page.locator('text=admin').first();
    await expect(usernameDisplay).toBeVisible();
  });
});
