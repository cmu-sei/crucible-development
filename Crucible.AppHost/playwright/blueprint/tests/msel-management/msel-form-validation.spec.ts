// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('MSEL Form Validation', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list and click 'Create MSEL'
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
    
    // 2. Leave the Name field empty and try to submit the form
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    
    // Ensure name field is empty
    await nameField.clear();
    await expect(nameField).toHaveValue('');
    
    // Try to submit the form
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // expect: Validation error is displayed indicating Name is required
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
    
    // 3. Enter a name but set end date before start date
    await nameField.fill('Test MSEL for Validation');
    await expect(nameField).toHaveValue('Test MSEL for Validation');
    
    // Set start date to a later date
    const startDateField = page.locator('input[name*="start"], input[placeholder*="Start"]').first();
    if (await startDateField.isVisible({ timeout: 2000 })) {
      await startDateField.fill('2026-04-30');
    }
    
    // Set end date to an earlier date
    const endDateField = page.locator('input[name*="end"], input[placeholder*="End"]').first();
    if (await endDateField.isVisible({ timeout: 2000 })) {
      await endDateField.fill('2026-04-01');
    }
    
    // Try to submit again
    await saveButton.click();
    
    // expect: Validation error indicates end date must be after start date
    const dateValidationError = page.locator(
      'text=/.*[Ee]nd.*[Dd]ate.*after.*[Ss]tart.*/, ' +
      'text=/.*[Dd]ate.*range.*/, ' +
      'text=/.*[Ii]nvalid.*[Dd]ate.*/, ' +
      '[class*="error"]:near(input[name*="end"]), ' +
      'mat-error:near(input[name*="end"])'
    ).first();
    await expect(dateValidationError).toBeVisible({ timeout: 5000 });
    
    // expect: Form submission is prevented
    await expect(form).toBeVisible();
    
    // 4. Fill all required fields correctly
    // Update end date to be after start date
    if (await endDateField.isVisible({ timeout: 2000 })) {
      await endDateField.clear();
      await endDateField.fill('2026-05-30');
    }
    
    // Fill description if required
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.fill('Test MSEL created for validation testing');
    }
    
    // expect: Validation passes
    // No validation errors should be visible
    await page.waitForTimeout(500);
    
    // expect: Save button becomes enabled
    // Check if the save button is enabled (not disabled)
    const isDisabled = await saveButton.isDisabled();
    expect(isDisabled).toBe(false);
    
    // expect: Form can be submitted
    await saveButton.click();
    
    // Wait for form to close or success notification
    await page.waitForTimeout(2000);
    
    // Check for success notification
    const notification = page.locator(
      '[class*="snack"], ' +
      '[class*="toast"], ' +
      '[class*="notification"], ' +
      'text=success, ' +
      'text=created'
    ).first();
    
    // Either form closes (not visible) or success notification appears
    const formClosed = !(await form.isVisible({ timeout: 2000 }).catch(() => false));
    const notificationVisible = await notification.isVisible({ timeout: 2000 }).catch(() => false);
    
    expect(formClosed || notificationVisible).toBe(true);
  });
});
