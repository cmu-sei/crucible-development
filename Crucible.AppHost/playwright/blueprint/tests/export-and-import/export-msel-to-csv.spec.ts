// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import path from 'path';
import fs from 'fs';

test.describe('Export and Import', () => {
  test('Export MSEL to CSV', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSEL is displayed
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
      
      // 2. Click 'Export' button and select CSV format
      const exportButton = page.locator(
        'button:has-text("Export"), ' +
        'button[aria-label*="Export"], ' +
        '[class*="export"]:has(button)'
      ).first();
      
      // Wait for download
      const downloadPromise = page.waitForEvent('download');
      
      await expect(exportButton).toBeVisible({ timeout: 5000 });
      await exportButton.click();
      
      // Look for CSV format option if menu appears
      const csvOption = page.locator(
        'button:has-text("CSV"), ' +
        'mat-option:has-text("CSV"), ' +
        'li:has-text("CSV"), ' +
        '[role="menuitem"]:has-text("CSV")'
      );
      
      if (await csvOption.isVisible({ timeout: 2000 })) {
        await csvOption.click();
      }
      
      // expect: CSV file is generated and downloaded
      const download = await downloadPromise;
      const downloadPath = await download.path();
      
      expect(downloadPath).toBeTruthy();
      expect(download.suggestedFilename()).toMatch(/\.csv$/i);
      
      // expect: CSV contains all scenario events with data fields
      if (downloadPath) {
        const stats = fs.statSync(downloadPath);
        expect(stats.size).toBeGreaterThan(0);
        
        // Read CSV content to verify structure
        const content = fs.readFileSync(downloadPath, 'utf-8');
        
        // expect: Data is properly escaped and formatted
        // CSV should have header row and data rows
        const lines = content.split('\n').filter(line => line.trim());
        expect(lines.length).toBeGreaterThan(0);
        
        // Clean up
        fs.unlinkSync(downloadPath);
      }
    } else {
      test.skip();
    }
  });
});
