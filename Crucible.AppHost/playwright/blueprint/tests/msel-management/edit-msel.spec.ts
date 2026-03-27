// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('Edit MSEL', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is visible with at least one MSEL
    const mselItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr, ' +
      'a[href*="msel"]'
    );
    
    const itemCount = await mselItems.count();
    
    if (itemCount > 0) {
      // 2. Click on an existing MSEL or click its edit icon
      const editButton = page.locator(
        'button[title*="Edit"], ' +
        'button[aria-label*="Edit"], ' +
        'mat-icon:has-text("edit")'
      ).first();
      
      if (await editButton.isVisible({ timeout: 2000 })) {
        await editButton.click();
      } else {
        // Click on the MSEL item itself
        await mselItems.first().click();
      }
      
      await page.waitForTimeout(1000);
      
      // expect: The MSEL edit page is displayed
      // expect: Form fields are populated with current values
      const descriptionField = page.locator(
        'textarea[name="description"], ' +
        'textarea[formControlName="description"], ' +
        'input[name="description"]'
      ).first();
      
      await expect(descriptionField).toBeVisible({ timeout: 5000 });
      
      const currentDescription = await descriptionField.inputValue();
      
      // 3. Modify the Description field
      const newDescription = `Updated description - ${Date.now()}`;
      await descriptionField.fill(newDescription);
      
      // expect: The description field accepts the new value
      await expect(descriptionField).toHaveValue(newDescription);
      
      // 4. Change the end date
      const endDateField = page.locator(
        'input[name*="end"], ' +
        'input[formControlName*="end"], ' +
        'input[placeholder*="End"]'
      ).first();
      
      if (await endDateField.isVisible({ timeout: 2000 })) {
        await endDateField.fill('2026-05-31');
        
        // expect: The date field accepts the updated value
        await expect(endDateField).toHaveValue('2026-05-31');
      }
      
      // 5. Click 'Save' button
      const saveButton = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Update"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveButton.click();
      
      // expect: The MSEL is updated successfully
      await page.waitForTimeout(2000);
      
      // expect: A success notification is displayed
      const notification = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        '[class*="notification"], ' +
        'text=success, ' +
        'text=updated, ' +
        'text=saved'
      );
      await expect(notification.first()).toBeVisible({ timeout: 5000 });
      
      // expect: Updated values are reflected in the MSEL list
      await page.waitForLoadState('networkidle');
      
      // expect: Modification timestamp is updated
      // This would be visible in the MSEL details or list
    } else {
      // Skip test if no MSELs exist
      test.skip();
    }
  });
});
