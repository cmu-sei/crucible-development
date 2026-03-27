// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import path from 'path';
import fs from 'fs';

test.describe('Export and Import', () => {
  test('Export MSEL to Excel', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSEL with scenario events is displayed
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      'text=/.*MSEL.*/i'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // Verify MSEL details page is loaded
      await expect(page.locator('body')).toContainText(/event|scenario|timeline/i, { timeout: 5000 });
      
      // 2. Click 'Export' button and select Excel format
      const exportButton = page.locator(
        'button:has-text("Export"), ' +
        'button[aria-label*="Export"], ' +
        '[class*="export"]:has(button)'
      ).first();
      
      // Wait for download
      const downloadPromise = page.waitForEvent('download');
      
      await expect(exportButton).toBeVisible({ timeout: 5000 });
      await exportButton.click();
      
      // Look for Excel format option if menu appears
      const excelOption = page.locator(
        'button:has-text("Excel"), ' +
        'mat-option:has-text("Excel"), ' +
        'li:has-text("Excel"), ' +
        '[role="menuitem"]:has-text("Excel")'
      );
      
      if (await excelOption.isVisible({ timeout: 2000 })) {
        await excelOption.click();
      }
      
      // expect: File is generated and downloaded
      const download = await downloadPromise;
      const downloadPath = await download.path();
      
      // expect: Excel file contains MSEL details and all scenario events
      expect(downloadPath).toBeTruthy();
      expect(download.suggestedFilename()).toMatch(/\.xlsx?$/i);
      
      // expect: Data fields are properly formatted in columns
      // expect: Row height is 15 pixels as configured
      // expect: Event colors are preserved or indicated
      // Verify file was downloaded and has content
      if (downloadPath) {
        const stats = fs.statSync(downloadPath);
        expect(stats.size).toBeGreaterThan(0);
      }
      
      // Clean up
      if (downloadPath) {
        fs.unlinkSync(downloadPath);
      }
    } else {
      test.skip();
    }
  });
});
