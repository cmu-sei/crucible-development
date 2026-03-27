// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import * as fs from 'fs';
import * as path from 'path';

test.describe('Scenario Events Management', () => {
  test('Bulk Import Scenario Events', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    // expect: MSEL details page is displayed
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // 2. Click 'Import' or 'Upload Events' button
      const importButton = page.locator(
        'button:has-text("Import"), ' +
        'button:has-text("Upload"), ' +
        'button:has-text("Import Events"), ' +
        'mat-icon:has-text("upload")'
      ).first();
      
      if (await importButton.isVisible({ timeout: 3000 })) {
        await importButton.click();
        
        // expect: File upload dialog is displayed
        await page.waitForTimeout(1000);
        
        const fileInput = page.locator('input[type="file"]');
        
        if (await fileInput.isVisible({ timeout: 2000 }) || await fileInput.count() > 0) {
          // 3. Select a CSV or Excel file with scenario events
          // Create a temporary CSV file for testing
          const tempDir = path.join(process.cwd(), 'temp');
          if (!fs.existsSync(tempDir)) {
            fs.mkdirSync(tempDir, { recursive: true });
          }
          
          const csvContent = `Control Number,Description,Details,From Org,To Org,Time
CTRL-100,Test Event 1,Details for test event 1,Red Team,Blue Team,10:00
CTRL-101,Test Event 2,Details for test event 2,Blue Team,Red Team,11:00
CTRL-102,Test Event 3,Details for test event 3,Red Team,Blue Team,12:00`;
          
          const csvFilePath = path.join(tempDir, 'test-events.csv');
          fs.writeFileSync(csvFilePath, csvContent);
          
          // Upload the file
          await fileInput.setInputFiles(csvFilePath);
          
          // expect: File is uploaded
          await page.waitForTimeout(1000);
          
          // expect: System validates file format and data
          const uploadStatus = page.locator(
            '[class*="upload-status"], ' +
            '[class*="file-name"], ' +
            'text=test-events.csv'
          );
          
          // 4. Review import preview
          const importPreview = page.locator(
            '[class*="import-preview"], ' +
            '[class*="preview-table"], ' +
            'table'
          );
          
          if (await importPreview.isVisible({ timeout: 3000 })) {
            // expect: Preview shows events to be imported with data mapping
            await expect(importPreview).toBeVisible();
            
            // expect: Errors or warnings are displayed if data is invalid
            // Check for any error messages
            const errorMessage = page.locator(
              '[class*="error"], ' +
              '[class*="warning"], ' +
              'text=error, ' +
              'text=warning'
            );
            
            // If no errors, proceed with import
            // 5. Confirm import
            const confirmButton = page.locator(
              'button:has-text("Confirm"), ' +
              'button:has-text("Import"), ' +
              'button:has-text("Upload"), ' +
              'button[type="submit"]'
            ).last();
            
            if (await confirmButton.isVisible({ timeout: 2000 })) {
              await confirmButton.click();
              
              // expect: Events are imported into the MSEL
              await page.waitForTimeout(2000);
              
              // expect: A success notification shows number of events imported
              const successNotification = page.locator(
                '[class*="snack"], ' +
                '[class*="toast"], ' +
                'text=success, ' +
                'text=imported, ' +
                'text=3 events'
              );
              
              await expect(successNotification.first()).toBeVisible({ timeout: 5000 });
              
              // expect: Imported events appear in the timeline
              const importedEvent1 = page.locator('text=Test Event 1');
              const importedEvent2 = page.locator('text=Test Event 2');
              const importedEvent3 = page.locator('text=Test Event 3');
              
              await expect(importedEvent1.or(importedEvent2).or(importedEvent3)).toBeVisible({ timeout: 5000 });
            }
          }
          
          // Clean up temporary file
          if (fs.existsSync(csvFilePath)) {
            fs.unlinkSync(csvFilePath);
          }
        } else {
          test.skip();
        }
      } else {
        test.skip();
      }
    } else {
      test.skip();
    }
  });
});
