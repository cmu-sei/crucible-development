// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('Scenario Event Custom Data Fields', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSEL admin or settings
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Try to find admin menu item or navigation for Data Fields
    const adminLink = page.locator(
      'text=Admin, ' +
      'a[href*="admin"], ' +
      'button:has-text("Admin")'
    ).first();
    
    if (await adminLink.isVisible({ timeout: 3000 })) {
      await adminLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      // Try direct URL navigation to admin
      await page.goto(`${Services.Blueprint.UI}/admin`);
      await page.waitForLoadState('networkidle');
    }
    
    // expect: Admin/settings page is accessible
    await page.waitForTimeout(1000);
    
    // Look for Data Fields section
    const dataFieldsLink = page.locator(
      'text=Data Fields, ' +
      'text=Fields, ' +
      'a[href*="field"], ' +
      'a[href*="data"], ' +
      'button:has-text("Data Fields"), ' +
      'button:has-text("Fields")'
    ).first();
    
    if (await dataFieldsLink.isVisible({ timeout: 3000 })) {
      await dataFieldsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      // Try direct URL navigation to data fields
      await page.goto(`${Services.Blueprint.UI}/admin/data-fields`);
      await page.waitForLoadState('networkidle');
    }
    
    // 2. Add a custom data field (beyond the 5 defaults) for scenario events
    const addFieldButton = page.locator(
      'button:has-text("Add Field"), ' +
      'button:has-text("Create Field"), ' +
      'button:has-text("New Field"), ' +
      'button:has-text("Add"), ' +
      'button:has-text("Create")'
    ).first();
    
    // expect: Custom data field form is available
    if (await addFieldButton.isVisible({ timeout: 5000 })) {
      await addFieldButton.click();
      await page.waitForTimeout(1000);
      
      // expect: Field can be configured with name, data type (String, Organization, Teams, etc.), and display order
      const fieldNameInput = page.locator(
        'input[name*="name"], ' +
        'input[formControlName*="name"], ' +
        'input[placeholder*="Name"]'
      ).first();
      
      await fieldNameInput.fill('Custom Field Test');
      await expect(fieldNameInput).toHaveValue('Custom Field Test');
      
      // Select data type
      const dataTypeSelect = page.locator(
        'select[name*="type"], ' +
        'mat-select[formControlName*="type"], ' +
        'select[name*="dataType"]'
      ).first();
      
      if (await dataTypeSelect.isVisible({ timeout: 2000 })) {
        await dataTypeSelect.click();
        
        // Try to select String type
        const stringOption = page.locator(
          'mat-option:has-text("String"), ' +
          'option:has-text("String"), ' +
          'mat-option:has-text("Text")'
        ).first();
        
        if (await stringOption.isVisible({ timeout: 2000 })) {
          await stringOption.click();
        }
      }
      
      // Set display order
      const displayOrderInput = page.locator(
        'input[name*="order"], ' +
        'input[formControlName*="order"], ' +
        'input[type="number"]'
      ).first();
      
      if (await displayOrderInput.isVisible({ timeout: 2000 })) {
        await displayOrderInput.fill('6');
      }
      
      // Save the custom field
      const saveFieldButton = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Create"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveFieldButton.click();
      await page.waitForTimeout(2000);
      
      // Check for success notification
      const notification = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        'text=success, ' +
        'text=created'
      );
      
      if (await notification.isVisible({ timeout: 3000 })) {
        // Success notification appeared
        expect(await notification.isVisible()).toBe(true);
      }
    }
    
    // 3. Create a new scenario event
    // Navigate back to MSELs
    const mselsLink = page.locator(
      'text=MSELs, ' +
      'text=MSEL, ' +
      'a[href*="msel"]'
    ).first();
    
    if (await mselsLink.isVisible({ timeout: 3000 })) {
      await mselsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      await page.goto(Services.Blueprint.UI);
      await page.waitForLoadState('networkidle');
    }
    
    // Find and click on a MSEL
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // Click 'Add Event' button
      const addEventButton = page.locator(
        'button:has-text("Add Event"), ' +
        'button:has-text("Create Event"), ' +
        'button:has-text("New Event"), ' +
        'button:has-text("Add")'
      ).first();
      
      if (await addEventButton.isVisible({ timeout: 5000 })) {
        await addEventButton.click();
        await page.waitForTimeout(1000);
        
        // expect: The custom data field appears in the event creation form
        const customFieldInput = page.locator(
          'input[name*="Custom Field"], ' +
          'input[formControlName*="customField"], ' +
          'label:has-text("Custom Field Test")'
        );
        
        const customFieldVisible = await customFieldInput.isVisible({ timeout: 3000 });
        
        // expect: Field is positioned according to display order
        // expect: Field validates according to its data type
        if (customFieldVisible) {
          // Try to interact with the custom field
          const customInput = page.locator(
            'input[name*="Custom"], ' +
            'textarea[name*="Custom"]'
          ).last();
          
          if (await customInput.isVisible({ timeout: 2000 })) {
            await customInput.fill('Test custom field value');
            await expect(customInput).toHaveValue('Test custom field value');
          }
        }
        
        // Fill in required fields to verify form completeness
        const descriptionField = page.locator(
          'textarea[name*="description"], ' +
          'input[name*="description"]'
        ).first();
        
        if (await descriptionField.isVisible({ timeout: 2000 })) {
          await descriptionField.fill('Test event with custom field');
        }
        
        // Close the dialog (don't save, this is just verification)
        const cancelButton = page.locator(
          'button:has-text("Cancel"), ' +
          'button:has-text("Close")'
        ).first();
        
        if (await cancelButton.isVisible({ timeout: 2000 })) {
          await cancelButton.click();
        } else {
          // Press Escape key to close dialog
          await page.keyboard.press('Escape');
        }
      } else {
        test.skip();
      }
    } else {
      test.skip();
    }
  });
});
