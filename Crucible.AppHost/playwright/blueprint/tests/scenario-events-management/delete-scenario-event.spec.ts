// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('Delete Scenario Event', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL with scenario events
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Find and click on a MSEL
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL details page shows events
      await page.waitForTimeout(1000);
      
      // Check if there are any events to delete
      const eventItems = page.locator(
        '[class*="event-item"], ' +
        '[class*="timeline-item"], ' +
        '[class*="scenario-event"], ' +
        'table tbody tr'
      );
      
      const eventCount = await eventItems.count();
      
      if (eventCount > 0) {
        // 2. Click the delete icon for a specific event
        const deleteButton = page.locator(
          'button[title*="Delete"], ' +
          'button[aria-label*="Delete"], ' +
          'button[aria-label*="delete"], ' +
          'mat-icon:has-text("delete")'
        ).first();
        
        await expect(deleteButton).toBeVisible({ timeout: 5000 });
        await deleteButton.click();
        
        // expect: A confirmation dialog appears
        await page.waitForTimeout(500);
        const confirmDialog = page.locator(
          '[role="dialog"], ' +
          '[class*="dialog"], ' +
          '[class*="modal"], ' +
          '.mat-dialog-container'
        );
        await expect(confirmDialog).toBeVisible({ timeout: 5000 });
        
        // 3. Click 'Cancel'
        const cancelButton = page.locator(
          'button:has-text("Cancel"), ' +
          'button:has-text("No")'
        ).first();
        await cancelButton.click();
        
        // expect: Dialog closes
        await page.waitForTimeout(500);
        await expect(confirmDialog).not.toBeVisible();
        
        // expect: Event is not deleted
        const countAfterCancel = await eventItems.count();
        expect(countAfterCancel).toBe(eventCount);
        
        // 4. Click delete icon again and confirm
        await deleteButton.click();
        
        // Wait for dialog to appear again
        await expect(confirmDialog).toBeVisible({ timeout: 5000 });
        
        // Click confirm/delete button
        const confirmButton = page.locator(
          'button:has-text("Delete"), ' +
          'button:has-text("Confirm"), ' +
          'button:has-text("Yes"), ' +
          'button:has-text("OK")'
        ).last();
        await confirmButton.click();
        
        // expect: The event is deleted successfully
        await page.waitForTimeout(2000);
        
        // expect: A success notification is displayed
        const notification = page.locator(
          '[class*="snack"], ' +
          '[class*="toast"], ' +
          '[class*="notification"], ' +
          'text=success, ' +
          'text=deleted, ' +
          'text=removed'
        );
        await expect(notification.first()).toBeVisible({ timeout: 5000 });
        
        // expect: Event is removed from the timeline
        await page.waitForLoadState('networkidle');
        await page.waitForTimeout(1000);
        const countAfterDelete = await eventItems.count();
        expect(countAfterDelete).toBe(eventCount - 1);
      } else {
        // Skip test if no events exist in this MSEL
        test.skip();
      }
    } else {
      // Skip test if no MSELs exist
      test.skip();
    }
  });
});
