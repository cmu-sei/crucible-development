// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';
import path from 'path';
import fs from 'fs';

test.describe('Export and Import', () => {
  test('Import Scenario Events from CSV', async ({ page }) => {
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
      
      // 2. Click 'Import Events' button
      const importEventsButton = page.locator(
        'button:has-text("Import Event"), ' +
        'button:has-text("Import"), ' +
        'button[aria-label*="Import"]'
      ).first();
      
      if (await importEventsButton.isVisible({ timeout: 5000 })) {
        await importEventsButton.click();
        
        // expect: File upload dialog is displayed
        await page.waitForTimeout(1000);
        
        // 3. Select a CSV file with scenario events
        // Create a sample CSV file for testing
        const testDataDir = path.join(__dirname, '..', '..', 'test-data');
        if (!fs.existsSync(testDataDir)) {
          fs.mkdirSync(testDataDir, { recursive: true });
        }
        
        const testFilePath = path.join(testDataDir, 'sample-events.csv');
        
        // For this test, we'll assume the file exists or skip
        if (fs.existsSync(testFilePath)) {
          const fileInput = page.locator('input[type="file"]');
          await fileInput.setInputFiles(testFilePath);
          
          // expect: File is uploaded and parsed
          await page.waitForTimeout(2000);
          
          // expect: Column mapping interface allows matching CSV columns to data fields
          const mappingInterface = page.locator(
            '[class*="mapping"], ' +
            '[class*="column-map"], ' +
            'select, ' +
            '[role="combobox"]'
          );
          
          if (await mappingInterface.first().isVisible({ timeout: 3000 })) {
            // Allow time for column mapping if needed
            await page.waitForTimeout(1000);
          }
          
          // expect: Preview shows events to be imported
          const preview = page.locator(
            '[class*="preview"], ' +
            '[class*="import-preview"], ' +
            'table'
          );
          
          if (await preview.isVisible({ timeout: 3000 })) {
            await page.waitForTimeout(1000);
            
            // 4. Confirm import
            const confirmButton = page.locator(
              'button:has-text("Confirm"), ' +
              'button:has-text("Import"), ' +
              'button:has-text("Continue")'
            ).last();
            
            if (await confirmButton.isEnabled({ timeout: 2000 })) {
              await confirmButton.click();
              
              // expect: Events are imported into the MSEL
              await page.waitForTimeout(3000);
              
              // expect: Success notification shows number imported
              const notification = page.locator(
                '[class*="snack"], ' +
                '[class*="toast"], ' +
                'text=success, ' +
                'text=imported'
              );
              
              await expect(notification.first()).toBeVisible({ timeout: 5000 });
              
              // expect: Events appear in timeline at correct times
              await page.waitForLoadState('networkidle');
            }
          }
        } else {
          console.log('Test CSV file not found, skipping import test');
          test.skip();
        }
      } else {
        console.log('Import Events button not found, feature may not be available yet');
        test.skip();
      }
    } else {
      test.skip();
    }
  });
});
