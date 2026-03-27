// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Home Page and Navigation', () => {
  test('Navigation to Admin Section', async ({ page }) => {
    // 1. Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Successfully authenticated on home page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    const topbarText = page.locator('text=Blueprint - Collaborative MSEL Creation');
    await expect(topbarText).toBeVisible();
    
    // 2. Navigate to admin section (if available via menu or URL)
    // Try to find admin menu item or navigation
    const adminLink = page.locator('text=Admin, a[href*="admin"], button:has-text("Admin")').first();
    
    if (await adminLink.isVisible({ timeout: 3000 })) {
      await adminLink.click();
    } else {
      // Try direct URL navigation
      await page.goto(`${Services.Blueprint.UI}/admin`);
    }
    
    // expect: The admin interface loads
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveURL(/.*admin.*/, { timeout: 5000 });
    
    // expect: A navigation menu is visible (sidebar or top navigation)
    const navigationMenu = page.locator('[class*="nav"], [class*="menu"], [class*="sidebar"]').first();
    await expect(navigationMenu).toBeVisible({ timeout: 5000 });
    
    // expect: Admin sections are accessible: MSELs, Teams, Users, Data Fields, etc.
    const adminSections = [
      page.locator('text=MSELs, text=MSEL'),
      page.locator('text=Teams, text=Team'),
      page.locator('text=Users, text=User'),
      page.locator('text=Data Fields, text=Fields')
    ];
    
    // At least one admin section should be visible
    let visibleSections = 0;
    for (const section of adminSections) {
      if (await section.isVisible({ timeout: 2000 })) {
        visibleSections++;
      }
    }
    expect(visibleSections).toBeGreaterThan(0);
  });
});
