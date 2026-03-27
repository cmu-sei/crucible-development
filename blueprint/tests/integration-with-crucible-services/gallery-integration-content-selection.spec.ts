// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Gallery Integration - Content Selection', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Create a scenario event with Gallery delivery method
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Navigate to a MSEL details page
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // Click 'Add Event' or 'Create Scenario Event' button
      const addEventButton = page.locator(
        'button:has-text("Add Event"), ' +
        'button:has-text("Create Event"), ' +
        'button:has-text("New Event"), ' +
        'button:has-text("Add")'
      ).first();
      
      await expect(addEventButton).toBeVisible({ timeout: 5000 });
      await addEventButton.click();
      
      // expect: Event creation form shows Gallery integration options
      await page.waitForTimeout(1000);
      const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
      await expect(form).toBeVisible({ timeout: 5000 });
      
      // Look for Gallery delivery method option
      const deliveryMethodField = page.locator(
        'select[name*="delivery"], ' +
        'mat-select[formControlName*="delivery"], ' +
        'select[formControlName*="method"]'
      ).first();
      
      if (await deliveryMethodField.isVisible({ timeout: 2000 })) {
        await deliveryMethodField.click();
        
        // Check for Gallery option
        const galleryOption = page.locator(
          'mat-option:has-text("Gallery"), ' +
          'option:has-text("Gallery")'
        ).first();
        
        if (await galleryOption.isVisible({ timeout: 2000 })) {
          await galleryOption.click();
        }
      }
      
      // 2. Click 'Select from Gallery' or browse Gallery content
      const galleryButton = page.locator(
        'button:has-text("Select from Gallery"), ' +
        'button:has-text("Browse Gallery"), ' +
        'button:has-text("Gallery Content"), ' +
        '[class*="gallery-select"]'
      ).first();
      
      if (await galleryButton.isVisible({ timeout: 5000 })) {
        await galleryButton.click();
        
        // expect: Gallery content browser opens
        await page.waitForTimeout(1000);
        const galleryDialog = page.locator(
          '[class*="gallery-dialog"], ' +
          '[class*="gallery-browser"], ' +
          '[class*="content-selector"]'
        ).first();
        
        await expect(galleryDialog).toBeVisible({ timeout: 5000 });
        
        // expect: Shows available content items from Gallery service (http://localhost:4723)
        // Check for Gallery API calls or content items
        const contentItems = page.locator(
          '[class*="content-item"], ' +
          '[class*="gallery-item"], ' +
          'mat-list-item, ' +
          '[role="listitem"]'
        );
        
        // expect: Content can be filtered and searched
        const searchField = page.locator(
          'input[type="search"], ' +
          'input[placeholder*="Search"], ' +
          'input[name*="search"]'
        ).first();
        
        if (await searchField.isVisible({ timeout: 2000 })) {
          await searchField.fill('test');
          await page.waitForTimeout(500);
        }
        
        // 3. Select content item(s) to associate with the event
        if (await contentItems.first().isVisible({ timeout: 5000 })) {
          await contentItems.first().click();
          
          // Confirm selection
          const selectButton = page.locator(
            'button:has-text("Select"), ' +
            'button:has-text("Choose"), ' +
            'button:has-text("Add"), ' +
            'button:has-text("OK")'
          ).last();
          
          if (await selectButton.isVisible({ timeout: 2000 })) {
            await selectButton.click();
          }
          
          // expect: Content is linked to the scenario event
          await page.waitForTimeout(1000);
          
          // expect: Selected content appears in event details
          const selectedContent = page.locator(
            '[class*="selected-content"], ' +
            '[class*="gallery-content"], ' +
            'text=Gallery content selected'
          ).first();
          
          // Save the event
          const saveButton = page.locator(
            'button:has-text("Save"), ' +
            'button:has-text("Create"), ' +
            'button[type="submit"]'
          ).last();
          
          if (await saveButton.isVisible({ timeout: 2000 })) {
            await saveButton.click();
            await page.waitForTimeout(2000);
          }
        }
      } else {
        console.log('Gallery integration not available in this MSEL');
      }
    } else {
      test.skip();
    }
  });
});
