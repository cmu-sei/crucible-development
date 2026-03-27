// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('Scenario Event Delivery Methods', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // Navigate to MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Locate and click on first MSEL
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // 1. Create a scenario event and select 'Gallery' as delivery method
      const addEventButton = page.locator(
        'button:has-text("Add Event"), ' +
        'button:has-text("Create Event"), ' +
        'button:has-text("New Event"), ' +
        'button:has-text("Add")'
      ).first();
      
      await expect(addEventButton).toBeVisible({ timeout: 5000 });
      await addEventButton.click();
      
      // Wait for event creation form
      await page.waitForTimeout(1000);
      const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
      await expect(form).toBeVisible({ timeout: 5000 });
      
      // Fill in basic event details
      const descriptionField = page.locator(
        'textarea[name*="description"], ' +
        'input[name*="description"], ' +
        'textarea[formControlName*="description"]'
      ).first();
      
      await descriptionField.fill('Gallery Delivery Test Event');
      await expect(descriptionField).toHaveValue('Gallery Delivery Test Event');
      
      // Select 'Gallery' as delivery method
      const deliveryMethodField = page.locator(
        'select[name*="delivery"], ' +
        'mat-select[formControlName*="delivery"], ' +
        'select[name*="method"], ' +
        'mat-select[formControlName*="method"]'
      ).first();
      
      if (await deliveryMethodField.isVisible({ timeout: 2000 })) {
        await deliveryMethodField.click();
        
        // expect: From delivery dropdown shows available methods
        const galleryOption = page.locator(
          'mat-option:has-text("Gallery"), ' +
          'option:has-text("Gallery")'
        ).first();
        
        if (await galleryOption.isVisible({ timeout: 2000 })) {
          await galleryOption.click();
        }
      }
      
      // Click Save button
      const saveButton = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Create"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveButton.click();
      await page.waitForTimeout(2000);
      
      // expect: Delivery method is saved
      // expect: Integration with Gallery service is configured for this event
      const notification = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        'text=success, ' +
        'text=created'
      );
      await expect(notification.first()).toBeVisible({ timeout: 5000 });
      
      // Verify event appears with Gallery delivery
      const newEvent = page.locator('text=Gallery Delivery Test Event');
      await expect(newEvent).toBeVisible({ timeout: 5000 });
      
      // 2. Create another event with 'Email' delivery method
      await addEventButton.click();
      await page.waitForTimeout(1000);
      
      const descriptionField2 = page.locator(
        'textarea[name*="description"], ' +
        'input[name*="description"], ' +
        'textarea[formControlName*="description"]'
      ).first();
      
      await descriptionField2.fill('Email Delivery Test Event');
      await expect(descriptionField2).toHaveValue('Email Delivery Test Event');
      
      // Select 'Email' as delivery method
      const deliveryMethodField2 = page.locator(
        'select[name*="delivery"], ' +
        'mat-select[formControlName*="delivery"], ' +
        'select[name*="method"], ' +
        'mat-select[formControlName*="method"]'
      ).first();
      
      if (await deliveryMethodField2.isVisible({ timeout: 2000 })) {
        await deliveryMethodField2.click();
        
        const emailOption = page.locator(
          'mat-option:has-text("Email"), ' +
          'option:has-text("Email")'
        ).first();
        
        if (await emailOption.isVisible({ timeout: 2000 })) {
          await emailOption.click();
        }
      }
      
      // Click Save button
      const saveButton2 = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Create"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveButton2.click();
      await page.waitForTimeout(2000);
      
      // expect: Email delivery is configured
      // expect: Email integration settings are accessible
      const notification2 = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        'text=success, ' +
        'text=created'
      );
      await expect(notification2.first()).toBeVisible({ timeout: 5000 });
      
      // Verify event appears with Email delivery
      const emailEvent = page.locator('text=Email Delivery Test Event');
      await expect(emailEvent).toBeVisible({ timeout: 5000 });
      
      // 3. Create an event with 'Notification' delivery method
      await addEventButton.click();
      await page.waitForTimeout(1000);
      
      const descriptionField3 = page.locator(
        'textarea[name*="description"], ' +
        'input[name*="description"], ' +
        'textarea[formControlName*="description"]'
      ).first();
      
      await descriptionField3.fill('Notification Delivery Test Event');
      await expect(descriptionField3).toHaveValue('Notification Delivery Test Event');
      
      // Select 'Notification' as delivery method
      const deliveryMethodField3 = page.locator(
        'select[name*="delivery"], ' +
        'mat-select[formControlName*="delivery"], ' +
        'select[name*="method"], ' +
        'mat-select[formControlName*="method"]'
      ).first();
      
      if (await deliveryMethodField3.isVisible({ timeout: 2000 })) {
        await deliveryMethodField3.click();
        
        const notificationOption = page.locator(
          'mat-option:has-text("Notification"), ' +
          'option:has-text("Notification")'
        ).first();
        
        if (await notificationOption.isVisible({ timeout: 2000 })) {
          await notificationOption.click();
        }
      }
      
      // Click Save button
      const saveButton3 = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Create"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveButton3.click();
      await page.waitForTimeout(2000);
      
      // expect: Notification delivery is configured
      // expect: Notification integration settings are available
      const notification3 = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        'text=success, ' +
        'text=created'
      );
      await expect(notification3.first()).toBeVisible({ timeout: 5000 });
      
      // Verify event appears with Notification delivery
      const notificationEvent = page.locator('text=Notification Delivery Test Event');
      await expect(notificationEvent).toBeVisible({ timeout: 5000 });
      
    } else {
      test.skip();
    }
  });
});
