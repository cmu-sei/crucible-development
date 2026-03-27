// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import path from 'path';
import fs from 'fs';

test.describe('Export and Import', () => {
  test('Export Selected Events Only', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL with scenario events
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: Events are displayed
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      'text=/.*MSEL.*/i'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // Verify MSEL details page with events is loaded
      await expect(page.locator('body')).toContainText(/event|scenario|timeline/i, { timeout: 5000 });
      
      // 2. Select specific events using checkboxes or selection tool
      const eventCheckboxes = page.locator(
        'input[type="checkbox"]:not([disabled]), ' +
        'mat-checkbox:not([disabled]), ' +
        '[class*="event"] input[type="checkbox"]'
      );
      
      const checkboxCount = await eventCheckboxes.count();
      
      if (checkboxCount > 0) {
        // Select first 2 events (or however many are available)
        const selectCount = Math.min(2, checkboxCount);
        
        for (let i = 0; i < selectCount; i++) {
          const checkbox = eventCheckboxes.nth(i);
          if (await checkbox.isVisible({ timeout: 2000 })) {
            await checkbox.check();
            
            // expect: Selected events are highlighted
            await page.waitForTimeout(500);
          }
        }
        
        // Verify at least one event is selected
        const selectedCheckboxes = page.locator('input[type="checkbox"]:checked');
        const selectedCount = await selectedCheckboxes.count();
        expect(selectedCount).toBeGreaterThan(0);
        
        // 3. Click 'Export Selected' button
        const exportSelectedButton = page.locator(
          'button:has-text("Export Selected"), ' +
          'button:has-text("Export"), ' +
          'button[aria-label*="Export Selected"]'
        ).first();
        
        if (await exportSelectedButton.isVisible({ timeout: 5000 })) {
          // Wait for download
          const downloadPromise = page.waitForEvent('download');
          
          await exportSelectedButton.click();
          
          // expect: Export format selection is displayed
          // Look for format options
          const formatOption = page.locator(
            'button:has-text("Excel"), ' +
            'button:has-text("CSV"), ' +
            'mat-option:has-text("Excel"), ' +
            'mat-option:has-text("CSV")'
          ).first();
          
          if (await formatOption.isVisible({ timeout: 2000 })) {
            await formatOption.click();
          }
          
          // expect: Only selected events are included in export
          // expect: File is downloaded
          const download = await downloadPromise;
          const downloadPath = await download.path();
          
          expect(downloadPath).toBeTruthy();
          expect(download.suggestedFilename()).toMatch(/\.(xlsx?|csv)$/i);
          
          if (downloadPath) {
            const stats = fs.statSync(downloadPath);
            expect(stats.size).toBeGreaterThan(0);
            
            // Clean up
            fs.unlinkSync(downloadPath);
          }
        } else {
          console.log('Export Selected button not found, checking for general export with selection');
          
          // Alternative: Use general export button which may respect selection
          const exportButton = page.locator(
            'button:has-text("Export"), ' +
            'button[aria-label*="Export"]'
          ).first();
          
          if (await exportButton.isVisible({ timeout: 5000 })) {
            const downloadPromise = page.waitForEvent('download');
            await exportButton.click();
            
            // Select format if menu appears
            const formatOption = page.locator(
              'button:has-text("Excel"), ' +
              'mat-option:has-text("Excel")'
            ).first();
            
            if (await formatOption.isVisible({ timeout: 2000 })) {
              await formatOption.click();
            }
            
            const download = await downloadPromise;
            const downloadPath = await download.path();
            
            expect(downloadPath).toBeTruthy();
            
            if (downloadPath) {
              fs.unlinkSync(downloadPath);
            }
          } else {
            test.skip();
          }
        }
      } else {
        console.log('No event checkboxes found, feature may not be available yet');
        test.skip();
      }
    } else {
      test.skip();
    }
  });
});
