// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Home Page and Navigation', () => {
  test('Browser Back and Forward Navigation', async ({ page }) => {
    // 1. Navigate to http://localhost:4725 and view the home page
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Home page loads
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    const homeUrl = page.url();
    
    // 2. Click on a MSEL from the list to view its details
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tr td a'
    ).first();
    
    // If MSEL link is available, click it
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      
      // expect: MSEL details page is displayed
      await page.waitForLoadState('networkidle');
      
      // expect: URL changes to include MSEL ID
      const mselUrl = page.url();
      expect(mselUrl).not.toBe(homeUrl);
      expect(mselUrl).toMatch(/msel|detail|view/i);
      
      // 3. Navigate to another section (e.g., Teams or Settings)
      const teamsLink = page.locator('a[href*="team"], button:has-text("Teams")').first();
      
      if (await teamsLink.isVisible({ timeout: 3000 })) {
        await teamsLink.click();
        await page.waitForLoadState('networkidle');
        
        // expect: New section is displayed
        // expect: URL changes accordingly
        const teamsUrl = page.url();
        expect(teamsUrl).not.toBe(mselUrl);
        expect(teamsUrl).toMatch(/team/i);
        
        // 4. Click browser back button
        await page.goBack();
        await page.waitForLoadState('networkidle');
        
        // expect: Application navigates back to MSEL details page
        // expect: MSEL details are displayed
        await expect(page).toHaveURL(mselUrl);
        
        // 5. Click browser back button again
        await page.goBack();
        await page.waitForLoadState('networkidle');
        
        // expect: Application navigates back to home page
        // expect: MSEL list is displayed
        await expect(page).toHaveURL(homeUrl);
        
        // 6. Click browser forward button
        await page.goForward();
        await page.waitForLoadState('networkidle');
        
        // expect: Application navigates forward to MSEL details
        // expect: Correct MSEL is displayed
        await expect(page).toHaveURL(mselUrl);
      }
    } else {
      // If no MSELs exist, create navigation history manually
      await page.goto(`${Services.Blueprint.UI}/teams`);
      await page.waitForLoadState('networkidle');
      const teamsUrl = page.url();
      
      await page.goBack();
      await page.waitForLoadState('networkidle');
      await expect(page).toHaveURL(homeUrl);
      
      await page.goForward();
      await page.waitForLoadState('networkidle');
      await expect(page).toHaveURL(teamsUrl);
    }
  });
});
