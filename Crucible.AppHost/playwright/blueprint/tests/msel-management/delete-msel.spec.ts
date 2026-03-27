// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('Delete MSEL', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is visible
    const mselItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    
    const initialCount = await mselItems.count();
    
    if (initialCount > 0) {
      // 2. Click the delete icon for a specific MSEL
      const deleteButton = page.locator(
        'button[title*="Delete"], ' +
        'button[aria-label*="Delete"], ' +
        'mat-icon:has-text("delete")'
      ).first();
      
      await expect(deleteButton).toBeVisible({ timeout: 5000 });
      await deleteButton.click();
      
      // expect: A confirmation dialog appears asking to confirm deletion
      await page.waitForTimeout(500);
      const confirmDialog = page.locator(
        '[role="dialog"], ' +
        '[class*="dialog"], ' +
        '[class*="modal"], ' +
        '.mat-dialog-container'
      );
      await expect(confirmDialog).toBeVisible({ timeout: 5000 });
      
      // 3. Click 'Cancel' in the confirmation dialog
      const cancelButton = page.locator(
        'button:has-text("Cancel"), ' +
        'button:has-text("No")'
      ).first();
      await cancelButton.click();
      
      // expect: The dialog closes
      await page.waitForTimeout(500);
      await expect(confirmDialog).not.toBeVisible();
      
      // expect: The MSEL is not deleted
      const countAfterCancel = await mselItems.count();
      expect(countAfterCancel).toBe(initialCount);
      
      // 4. Click the delete icon again
      await deleteButton.click();
      
      // expect: Confirmation dialog appears again
      await expect(confirmDialog).toBeVisible({ timeout: 5000 });
      
      // 5. Click 'Confirm' or 'Delete' button
      const confirmButton = page.locator(
        'button:has-text("Delete"), ' +
        'button:has-text("Confirm"), ' +
        'button:has-text("Yes"), ' +
        'button:has-text("OK")'
      ).last();
      await confirmButton.click();
      
      // expect: The MSEL is deleted successfully
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
      
      // expect: The MSEL is removed from the list
      await page.waitForLoadState('networkidle');
      const countAfterDelete = await mselItems.count();
      expect(countAfterDelete).toBe(initialCount - 1);
      
      // expect: If MSEL has associated events or data, deletion may be prevented with appropriate error message
      // This scenario would require a MSEL with dependencies
    } else {
      // Skip test if no MSELs exist
      test.skip();
    }
  });
});
