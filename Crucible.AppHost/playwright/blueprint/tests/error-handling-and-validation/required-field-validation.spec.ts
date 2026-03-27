// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Error Handling and Validation', () => {
  test('Required Field Validation', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Open any form with required fields
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
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
    
    // expect: Form is displayed with required field indicators
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // Check for required field indicators (asterisks, labels, etc.)
    const requiredIndicators = page.locator(
      'label:has-text("*"), ' +
      '[class*="required"], ' +
      '.required, ' +
      '[required]'
    );
    
    // At least one required field should be indicated
    const requiredCount = await requiredIndicators.count();
    expect(requiredCount).toBeGreaterThan(0);
    
    // 2. Leave required fields empty and attempt to submit
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    
    // Ensure name field is empty
    await nameField.clear();
    await expect(nameField).toHaveValue('');
    
    // Clear description if present
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.clear();
    }
    
    // Try to submit the form
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    await page.waitForTimeout(1000);
    
    // expect: Validation errors are displayed for each required field
    const validationErrors = page.locator(
      'text=/.*required.*/, ' +
      '[class*="error"], ' +
      '[class*="invalid"], ' +
      'mat-error, ' +
      '[role="alert"]'
    );
    
    const errorCount = await validationErrors.count();
    expect(errorCount).toBeGreaterThan(0);
    
    // expect: Error messages clearly indicate which fields are required
    const nameValidationError = page.locator(
      'text=/.*[Nn]ame.*required.*/, ' +
      'text=/.*required.*[Nn]ame.*/, ' +
      '[class*="error"]:near(input[name="name"]), ' +
      '[class*="invalid"]:near(input[name="name"]), ' +
      'mat-error:near(input[name="name"])'
    ).first();
    await expect(nameValidationError).toBeVisible({ timeout: 5000 });
    
    // expect: Form submission is prevented
    // The form should still be visible (not closed)
    await expect(form).toBeVisible();
    
    // expect: Required fields are visually highlighted
    // Check if name field has error styling
    const nameFieldClasses = await nameField.getAttribute('class');
    const hasErrorClass = nameFieldClasses?.includes('error') || 
                          nameFieldClasses?.includes('invalid') || 
                          nameFieldClasses?.includes('ng-invalid');
    
    // Or check if parent has error indication
    const nameFieldContainer = nameField.locator('xpath=ancestor::*[contains(@class, "error") or contains(@class, "invalid")]').first();
    const containerHasError = await nameFieldContainer.count() > 0;
    
    expect(hasErrorClass || containerHasError).toBe(true);
    
    // Now fill in the required field and verify validation clears
    await nameField.fill('Test MSEL for Required Field Validation');
    await expect(nameField).toHaveValue('Test MSEL for Required Field Validation');
    
    // Wait for validation to update
    await page.waitForTimeout(500);
    
    // Validation error should disappear
    const errorStillVisible = await nameValidationError.isVisible({ timeout: 2000 }).catch(() => false);
    expect(errorStillVisible).toBe(false);
    
    // Form should now be submittable
    await saveButton.click();
    await page.waitForTimeout(2000);
    
    // Check for success or that form processing occurred
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
