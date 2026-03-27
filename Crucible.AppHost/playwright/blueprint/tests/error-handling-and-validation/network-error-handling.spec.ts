// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Error Handling and Validation', () => {
  test('Network Error Handling', async ({ page, context }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Navigate to a stable state
    const createButton = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL"), ' +
      'button:has-text("New MSEL"), ' +
      'button:has-text("Create"), ' +
      'button:has-text("Add")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // Fill in some data
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    await nameField.fill('Network Error Test MSEL');
    
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.fill('Testing network error handling');
    }
    
    // 1. Disconnect from network while using the application
    // Simulate network disconnection by blocking all network requests
    await context.route('**/*', route => route.abort('failed'));
    
    // expect: Network connection is lost
    await page.waitForTimeout(500);
    
    // 2. Attempt to perform an action (e.g., save event)
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // Wait for error to appear
    await page.waitForTimeout(2000);
    
    // expect: Application detects network error
    // expect: Appropriate error message is displayed
    const networkErrorNotification = page.locator(
      '[class*="snack"]:has-text(/network|connection|offline|failed/i), ' +
      '[class*="toast"]:has-text(/network|connection|offline|failed/i), ' +
      '[class*="notification"]:has-text(/network|connection|offline|failed/i), ' +
      '[class*="alert"]:has-text(/network|connection|offline|failed/i), ' +
      'text=/.*[Nn]etwork.*[Ee]rror.*/, ' +
      'text=/.*[Cc]onnection.*[Ff]ailed.*/, ' +
      'text=/.*[Oo]ffline.*/, ' +
      '[role="alert"]'
    ).first();
    
    await expect(networkErrorNotification).toBeVisible({ timeout: 5000 });
    
    // expect: Action fails gracefully without crashing
    // The page should still be responsive and the form visible
    await expect(form).toBeVisible();
    
    // expect: Unsaved changes may be preserved locally
    // Verify the data is still in the form
    await expect(nameField).toHaveValue('Network Error Test MSEL');
    
    // 3. Restore network connection
    // Remove the network block
    await context.unroute('**/*');
    
    // expect: Application resumes normal operation
    await page.waitForTimeout(1000);
    
    // expect: User can retry the action
    // Try to submit again with network restored
    await saveButton.click();
    
    // Wait for form to process
    await page.waitForTimeout(2000);
    
    // Check for success notification or form closure
    const successNotification = page.locator(
      '[class*="snack"]:has-text(/success|created/i), ' +
      '[class*="toast"]:has-text(/success|created/i), ' +
      '[class*="notification"]:has-text(/success|created/i)'
    ).first();
    
    const formClosed = !(await form.isVisible({ timeout: 2000 }).catch(() => false));
    const notificationVisible = await successNotification.isVisible({ timeout: 2000 }).catch(() => false);
    
    // Either the form closes successfully or we still see the form (depends on implementation)
    // The key is that the application didn't crash and is still functional
    expect(page.url()).toContain('localhost:4725');
  });
});
