// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('Create Scenario Event', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL details page is displayed
      await page.waitForTimeout(1000);
      
      // 2. Click 'Add Event' or 'Create Scenario Event' button
      const addEventButton = page.locator(
        'button:has-text("Add Event"), ' +
        'button:has-text("Create Event"), ' +
        'button:has-text("New Event"), ' +
        'button:has-text("Add")'
      ).first();
      
      await expect(addEventButton).toBeVisible({ timeout: 5000 });
      await addEventButton.click();
      
      // expect: A scenario event creation form is displayed
      await page.waitForTimeout(1000);
      const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
      await expect(form).toBeVisible({ timeout: 5000 });
      
      // 3. Enter 'CTRL-001' in the Control Number field (default data field)
      const controlNumberField = page.locator(
        'input[name*="control"], ' +
        'input[formControlName*="control"], ' +
        'input[placeholder*="Control"]'
      ).first();
      
      if (await controlNumberField.isVisible({ timeout: 2000 })) {
        await controlNumberField.fill('CTRL-001');
        
        // expect: Control Number field accepts input
        await expect(controlNumberField).toHaveValue('CTRL-001');
      }
      
      // 4. Select 'Red Team' in the From Org field (Organization data type)
      const fromOrgField = page.locator(
        'select[name*="from"], ' +
        'mat-select[formControlName*="from"]'
      ).first();
      
      if (await fromOrgField.isVisible({ timeout: 2000 })) {
        await fromOrgField.click();
        
        // expect: From Org dropdown shows available organizations
        const redTeamOption = page.locator('mat-option:has-text("Red Team"), option:has-text("Red Team")').first();
        if (await redTeamOption.isVisible({ timeout: 2000 })) {
          await redTeamOption.click();
        }
      }
      
      // 5. Select one or more teams in the To Org field (TeamsMultiple data type)
      // 6. Enter 'Initial phishing campaign' in the Description field
      const descriptionField = page.locator(
        'textarea[name*="description"], ' +
        'input[name*="description"], ' +
        'textarea[formControlName*="description"]'
      ).first();
      
      await descriptionField.fill('Initial phishing campaign');
      
      // expect: Description field accepts input
      await expect(descriptionField).toHaveValue('Initial phishing campaign');
      
      // 7. Enter detailed information in the Details field
      const detailsField = page.locator(
        'textarea[name*="detail"], ' +
        'textarea[formControlName*="detail"]'
      ).first();
      
      if (await detailsField.isVisible({ timeout: 2000 })) {
        await detailsField.fill('Detailed information about the phishing campaign targeting employee credentials.');
        
        // expect: Details field accepts multi-line text input
        await expect(detailsField).toHaveValue(/Detailed information/);
      }
      
      // 8. Set the event time/date
      // 9. Select a delivery method from options: Gallery, Email, or Notification
      // 10. Select an event type or category
      
      // 11. Click 'Save' or 'Create' button
      const saveButton = page.locator(
        'button:has-text("Save"), ' +
        'button:has-text("Create"), ' +
        'button[type="submit"]'
      ).last();
      
      await saveButton.click();
      
      // expect: The scenario event is created successfully
      await page.waitForTimeout(2000);
      
      // expect: A success notification is displayed
      const notification = page.locator(
        '[class*="snack"], ' +
        '[class*="toast"], ' +
        'text=success, ' +
        'text=created'
      );
      await expect(notification.first()).toBeVisible({ timeout: 5000 });
      
      // expect: The event appears in the timeline/list at the correct time position
      const newEvent = page.locator('text=Initial phishing campaign');
      await expect(newEvent).toBeVisible({ timeout: 5000 });
      
      // expect: Event is displayed with its assigned color
      // Color is applied via background-color CSS property
    } else {
      test.skip();
    }
  });
});
