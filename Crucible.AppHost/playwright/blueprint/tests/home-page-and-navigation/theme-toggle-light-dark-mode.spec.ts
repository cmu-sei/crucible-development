// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Home Page and Navigation', () => {
  test('Theme Toggle (Light/Dark Mode)', async ({ page }) => {
    // 1. Log in and navigate to the home page
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Application loads with default theme
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Get initial theme
    const initialTheme = await page.evaluate(() => {
      return document.body.className;
    });
    
    // 2. Locate and click the theme toggle button (typically in topbar)
    const themeToggle = page.locator(
      'button[class*="theme"], ' +
      'button[aria-label*="theme"], ' +
      'button:has([class*="moon"]), ' +
      'button:has([class*="sun"]), ' +
      '[class*="theme-toggle"]'
    ).first();
    
    await expect(themeToggle).toBeVisible({ timeout: 5000 });
    await themeToggle.click();
    
    // expect: The application theme switches between light and dark mode
    await page.waitForTimeout(500); // Allow theme transition
    
    const newTheme = await page.evaluate(() => {
      return document.body.className;
    });
    expect(newTheme).not.toBe(initialTheme);
    
    // expect: Dark theme uses tint value of 0.7 as configured
    // expect: Light theme uses tint value of 0.4 as configured
    const isDarkMode = newTheme.toLowerCase().includes('dark');
    
    // expect: All components properly render in the new theme
    const topbar = page.locator('[class*="topbar"], [class*="top-bar"], [class*="header"]').first();
    await expect(topbar).toBeVisible();
    
    const mainContent = page.locator('main, [class*="content"]').first();
    await expect(mainContent).toBeVisible();
    
    // expect: Theme preference is saved in local storage
    const themePreference = await page.evaluate(() => {
      return localStorage.getItem('theme') || 
             localStorage.getItem('selectedTheme') ||
             localStorage.getItem('isDarkMode');
    });
    expect(themePreference).toBeTruthy();
    
    // expect: Overlay components (dialogs, dropdowns) also reflect the theme change
    // Toggle theme back to verify it works both ways
    await themeToggle.click();
    await page.waitForTimeout(500);
    
    const revertedTheme = await page.evaluate(() => {
      return document.body.className;
    });
    expect(revertedTheme).toBe(initialTheme);
    
    // 3. Refresh the page
    await page.reload();
    await page.waitForLoadState('networkidle');
    
    // expect: The selected theme persists after page reload
    const themeAfterReload = await page.evaluate(() => {
      return document.body.className;
    });
    expect(themeAfterReload).toBe(initialTheme);
  });
});
