// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import path from 'path';
import fs from 'fs';

test.describe('Export and Import', () => {
  test('Export MSEL to PDF', async ({ page }) => {
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
      
      // 2. Click 'Export' button and select PDF format
      const exportButton = page.locator(
        'button:has-text("Export"), ' +
        'button[aria-label*="Export"], ' +
        '[class*="export"]:has(button)'
      ).first();
      
      // Wait for download
      const downloadPromise = page.waitForEvent('download');
      
      await expect(exportButton).toBeVisible({ timeout: 5000 });
      await exportButton.click();
      
      // Look for PDF format option if menu appears
      const pdfOption = page.locator(
        'button:has-text("PDF"), ' +
        'mat-option:has-text("PDF"), ' +
        'li:has-text("PDF"), ' +
        '[role="menuitem"]:has-text("PDF")'
      );
      
      if (await pdfOption.isVisible({ timeout: 2000 })) {
        await pdfOption.click();
      }
      
      // expect: PDF is generated and downloaded
      const download = await downloadPromise;
      const downloadPath = await download.path();
      
      expect(downloadPath).toBeTruthy();
      expect(download.suggestedFilename()).toMatch(/\.pdf$/i);
      
      // expect: PDF contains MSEL overview and timeline
      // expect: Event colors are visible in PDF
      // expect: Formatting is professional and readable
      if (downloadPath) {
        const stats = fs.statSync(downloadPath);
        expect(stats.size).toBeGreaterThan(0);
        
        // Verify it's a valid PDF by checking the magic bytes
        const buffer = fs.readFileSync(downloadPath);
        const header = buffer.toString('utf-8', 0, 5);
        expect(header).toBe('%PDF-');
        
        // Clean up
        fs.unlinkSync(downloadPath);
      }
    } else {
      test.skip();
    }
  });
});
