// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Error Handling and Validation', () => {
  test('API Error Display', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Trigger an API error (e.g., create MSEL with invalid data)
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // expect: MSELs list is visible
    await page.waitForLoadState('networkidle');
    
    const createButton = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL"), ' +
      'button:has-text("New MSEL"), ' +
      'button:has-text("Create"), ' +
      'button:has-text("Add")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    // expect: MSEL creation form is displayed
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // Trigger an API error by submitting invalid data
    // Fill in name with extremely long string or special characters that violate API constraints
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    await nameField.clear();
    // Use a name that might exceed maximum length or contain invalid characters
    await nameField.fill('x'.repeat(1000)); // Extremely long name
    
    // Try to submit the form
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // 2. Observe application response
    await page.waitForTimeout(2000);
    
    // expect: Error notification or message is displayed
    const errorNotification = page.locator(
      '[class*="snack"]:has-text(/error|failed|invalid/i), ' +
      '[class*="toast"]:has-text(/error|failed|invalid/i), ' +
      '[class*="notification"]:has-text(/error|failed|invalid/i), ' +
      '[class*="alert"]:has-text(/error|failed|invalid/i), ' +
      'text=/.*[Ee]rror.*/, ' +
      'text=/.*[Ff]ailed.*/, ' +
      '[role="alert"]'
    ).first();
    
    await expect(errorNotification).toBeVisible({ timeout: 5000 });
    
    // expect: Error message is clear and actionable
    const errorText = await errorNotification.textContent();
    expect(errorText).toBeTruthy();
    expect(errorText?.length || 0).toBeGreaterThan(0);
    
    // expect: Form submission is prevented
    // The form should still be visible (not closed)
    await expect(form).toBeVisible();
    
    // expect: User can correct the error and retry
    // Clear the invalid name and enter a valid one
    await nameField.clear();
    await nameField.fill('Valid MSEL Name');
    await expect(nameField).toHaveValue('Valid MSEL Name');
    
    // Fill description if required
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.fill('Valid description for API error test');
    }
    
    // Try to submit again with valid data
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
    
    expect(formClosed || notificationVisible).toBe(true);
  });
});
