// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Home Page and Navigation', () => {
  test('Home Page Initial Load', async ({ page }) => {
    // 1. Log in as admin user and navigate to http://localhost:4725
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: The home page loads successfully
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: The topbar is visible with Blueprint branding
    const topbar = page.locator('[class*="topbar"], [class*="top-bar"], [class*="header"]').first();
    await expect(topbar).toBeVisible();
    
    // expect: The topbar displays 'Blueprint - Collaborative MSEL Creation'
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible();
    
    // expect: The topbar color is #2d69b4 with white text (#FFFFFF)
    const backgroundColor = await topbar.evaluate((el) => {
      return window.getComputedStyle(el).backgroundColor;
    });
    expect(backgroundColor).toMatch(/rgb\(45,\s*105,\s*180\)/);
    
    const textColor = await topbar.evaluate((el) => {
      return window.getComputedStyle(el).color;
    });
    expect(textColor).toMatch(/rgb\(255,\s*255,\s*255\)/);
    
    // expect: A pencil-ruler icon is displayed in the topbar
    const icon = page.locator('[class*="icon"], mat-icon, svg').first();
    await expect(icon).toBeVisible();
    
    // expect: The user's username is displayed in the topbar
    const usernameDisplay = page.locator('text=admin').first();
    await expect(usernameDisplay).toBeVisible();
    
    // expect: The main content area displays MSEL list or dashboard
    const mainContent = page.locator('main, [class*="content"], [class*="main"]').first();
    await expect(mainContent).toBeVisible();
  });
});
