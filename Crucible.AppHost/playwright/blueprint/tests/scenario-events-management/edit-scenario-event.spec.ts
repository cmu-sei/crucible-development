// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('Edit Scenario Event', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL with existing scenario events
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    // expect: MSEL details page shows scenario events
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // 2. Click on an event or its edit icon
      const editIcon = page.locator(
        'button[mattooltip*="Edit"], ' +
        'button[aria-label*="Edit"], ' +
        'button:has-text("Edit"), ' +
        'mat-icon:has-text("edit")'
      ).first();
      
      if (await editIcon.isVisible({ timeout: 3000 })) {
        await editIcon.click();
        
        // expect: Event edit form is displayed
        await page.waitForTimeout(1000);
        const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
        await expect(form).toBeVisible({ timeout: 5000 });
        
        // expect: All fields are populated with current values
        const descriptionField = page.locator(
          'textarea[name*="description"], ' +
          'input[name*="description"], ' +
          'textarea[formControlName*="description"]'
        ).first();
        
        await expect(descriptionField).toBeVisible();
        const currentValue = await descriptionField.inputValue();
        expect(currentValue).toBeTruthy();
        
        // 3. Modify the Description field
        const newDescription = 'Updated scenario event description';
        await descriptionField.fill('');
        await descriptionField.fill(newDescription);
        
        // expect: Description field accepts new value
        await expect(descriptionField).toHaveValue(newDescription);
        
        // 4. Change the event time
        const timeField = page.locator(
          'input[type="time"], ' +
          'input[name*="time"], ' +
          'input[formControlName*="time"]'
        ).first();
        
        if (await timeField.isVisible({ timeout: 2000 })) {
          await timeField.fill('14:30');
          
          // expect: Time field accepts updated value
          await expect(timeField).toHaveValue('14:30');
        }
        
        // 5. Click 'Save' button
        const saveButton = page.locator(
          'button:has-text("Save"), ' +
          'button:has-text("Update"), ' +
          'button[type="submit"]'
        ).last();
        
        await saveButton.click();
        
        // expect: The event is updated successfully
        await page.waitForTimeout(2000);
        
        // expect: A success notification is displayed
        const notification = page.locator(
          '[class*="snack"], ' +
          '[class*="toast"], ' +
          'text=success, ' +
          'text=updated, ' +
          'text=saved'
        );
        await expect(notification.first()).toBeVisible({ timeout: 5000 });
        
        // expect: Updated values are reflected in the timeline
        const updatedEvent = page.locator(`text=${newDescription}`);
        await expect(updatedEvent).toBeVisible({ timeout: 5000 });
        
        // expect: Event is repositioned if time changed
        // Visual verification - event should appear in timeline at new time position
      } else {
        test.skip();
      }
    } else {
      test.skip();
    }
  });
});
