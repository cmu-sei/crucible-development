// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect, chromium, BrowserContext } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Real-time Collaboration and SignalR', () => {
  test('Collaborative Editing Conflict Resolution', async ({ page }) => {
    // 1. Open two windows, both editing the same scenario event
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await page.waitForLoadState('networkidle');
    
    // Navigate to a MSEL with events
    const mselLink = page.locator('a[href*="/msel"], div[class*="msel"]').first();
    let mselUrl = '';
    
    if (await mselLink.isVisible({ timeout: 5000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      mselUrl = page.url();
    }
    
    // Find an event to edit
    const existingEvent = page.locator('[class*="event"], [class*="scenario"]').first();
    
    if (await existingEvent.isVisible({ timeout: 5000 })) {
      // Open edit form in window 1
      const editButton1 = existingEvent.locator('button[class*="edit"], mat-icon:has-text("edit")').first();
      
      if (await editButton1.isVisible({ timeout: 2000 })) {
        await editButton1.click();
      } else {
        await existingEvent.click();
      }
      
      await page.waitForTimeout(1000);
      
      // expect: Both windows have the event edit form open
      const descriptionField1 = page.locator(
        'input[name="description"], ' +
        'textarea[name="description"], ' +
        'input[formControlName="description"]'
      ).first();
      
      await expect(descriptionField1).toBeVisible({ timeout: 5000 });
      
      // Open second browser window with the same event
      const browser = await chromium.launch();
      const context2 = await browser.newContext({ ignoreHTTPSErrors: true });
      const page2 = await context2.newPage();
      
      await authenticateBlueprintWithKeycloak(page2, 'admin', 'admin');
      await page2.goto(mselUrl);
      await page2.waitForLoadState('networkidle');
      
      // Open edit form in window 2
      const existingEvent2 = page2.locator('[class*="event"], [class*="scenario"]').first();
      
      if (await existingEvent2.isVisible({ timeout: 5000 })) {
        const editButton2 = existingEvent2.locator('button[class*="edit"], mat-icon:has-text("edit")').first();
        
        if (await editButton2.isVisible({ timeout: 2000 })) {
          await editButton2.click();
        } else {
          await existingEvent2.click();
        }
        
        await page2.waitForTimeout(1000);
      }
      
      // 2. In window 1, modify and save the event
      const timestamp1 = new Date().toISOString();
      await descriptionField1.clear();
      await descriptionField1.fill('Modified in window 1 at ' + timestamp1);
      
      const saveButton1 = page.locator('button:has-text("Save"), button[type="submit"]').last();
      await saveButton1.click();
      
      // expect: Event is saved from window 1
      await page.waitForTimeout(2000);
      
      // 3. In window 2, make different changes and try to save
      const descriptionField2 = page2.locator(
        'input[name="description"], ' +
        'textarea[name="description"], ' +
        'input[formControlName="description"]'
      ).first();
      
      if (await descriptionField2.isVisible({ timeout: 2000 })) {
        const timestamp2 = new Date().toISOString();
        await descriptionField2.clear();
        await descriptionField2.fill('Modified in window 2 at ' + timestamp2);
        
        const saveButton2 = page2.locator('button:has-text("Save"), button[type="submit"]').last();
        await saveButton2.click();
        
        // expect: Conflict detection occurs
        // expect: User is notified that the event was modified by another user
        // expect: Options to reload, merge, or overwrite are presented
        
        await page2.waitForTimeout(2000);
        
        // Look for conflict notification, error message, or warning
        const conflictIndicators = page2.locator(
          'text=/conflict/i, ' +
          'text=/modified by another user/i, ' +
          'text=/concurrent edit/i, ' +
          'text=/outdated/i, ' +
          '[class*="error"], ' +
          '[class*="warning"], ' +
          '[class*="conflict"]'
        );
        
        // The application should either:
        // 1. Show a conflict notification
        // 2. Prevent the save with an error
        // 3. Force a reload/refresh of the data
        // 4. Show merge options
        
        const hasConflictUI = await conflictIndicators.first().isVisible({ timeout: 5000 }).catch(() => false);
        
        // If no explicit conflict UI, check if the save was prevented or if there's a validation error
        const errorMessage = page2.locator('[class*="error"], [role="alert"]');
        const hasError = await errorMessage.first().isVisible({ timeout: 2000 }).catch(() => false);
        
        // At minimum, we expect some indication of the conflict
        expect(hasConflictUI || hasError).toBeTruthy();
      }
      
      // Cleanup
      await context2.close();
      await browser.close();
    } else {
      // If no events exist, skip test with appropriate message
      test.skip(await existingEvent.isVisible({ timeout: 1000 }), 'No events available for conflict resolution test');
    }
  });
});
