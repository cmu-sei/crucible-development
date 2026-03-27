// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Error Handling and Validation', () => {
  test('Duplicate Name Validation', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Generate a unique name for this test run
    const uniqueName = `Duplicate Test MSEL ${Date.now()}`;
    
    // 1. Create a MSEL with a specific name
    const createButton = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL"), ' +
      'button:has-text("New MSEL"), ' +
      'button:has-text("Create"), ' +
      'button:has-text("Add")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // Fill in the form
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    await nameField.fill(uniqueName);
    await expect(nameField).toHaveValue(uniqueName);
    
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.fill('First MSEL for duplicate name testing');
    }
    
    // Set dates if required
    const startDateField = page.locator('input[name*="start"], input[placeholder*="Start"]').first();
    if (await startDateField.isVisible({ timeout: 2000 })) {
      await startDateField.fill('2026-04-01');
    }
    
    const endDateField = page.locator('input[name*="end"], input[placeholder*="End"]').first();
    if (await endDateField.isVisible({ timeout: 2000 })) {
      await endDateField.fill('2026-05-01');
    }
    
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // Wait for MSEL to be created
    await page.waitForTimeout(2000);
    
    // expect: MSEL is created successfully
    const successNotification = page.locator(
      '[class*="snack"]:has-text(/success|created/i), ' +
      '[class*="toast"]:has-text(/success|created/i), ' +
      '[class*="notification"]:has-text(/success|created/i)'
    ).first();
    
    const formClosed = !(await form.isVisible({ timeout: 2000 }).catch(() => false));
    const notificationVisible = await successNotification.isVisible({ timeout: 2000 }).catch(() => false);
    
    expect(formClosed || notificationVisible).toBe(true);
    
    // Wait for notification to disappear
    await page.waitForTimeout(3000);
    
    // 2. Attempt to create another MSEL with the same name
    // Click create button again
    const createButtonAgain = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL"), ' +
      'button:has-text("New MSEL"), ' +
      'button:has-text("Create"), ' +
      'button:has-text("Add")'
    ).first();
    
    await expect(createButtonAgain).toBeVisible({ timeout: 5000 });
    await createButtonAgain.click();
    
    await page.waitForTimeout(1000);
    const form2 = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form2).toBeVisible({ timeout: 5000 });
    
    // Fill in with the SAME name
    const nameField2 = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    await nameField2.fill(uniqueName);
    await expect(nameField2).toHaveValue(uniqueName);
    
    const descriptionField2 = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    if (await descriptionField2.isVisible({ timeout: 2000 })) {
      await descriptionField2.fill('Second MSEL attempting duplicate name');
    }
    
    // Set dates if required
    const startDateField2 = page.locator('input[name*="start"], input[placeholder*="Start"]').first();
    if (await startDateField2.isVisible({ timeout: 2000 })) {
      await startDateField2.fill('2026-04-01');
    }
    
    const endDateField2 = page.locator('input[name*="end"], input[placeholder*="End"]').first();
    if (await endDateField2.isVisible({ timeout: 2000 })) {
      await endDateField2.fill('2026-05-01');
    }
    
    const saveButton2 = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton2.click();
    
    await page.waitForTimeout(2000);
    
    // expect: Validation error indicates duplicate name
    const duplicateError = page.locator(
      'text=/.*[Dd]uplicate.*[Nn]ame.*/, ' +
      'text=/.*[Nn]ame.*[Aa]lready.*[Ee]xists.*/, ' +
      'text=/.*[Nn]ame.*[Tt]aken.*/, ' +
      'text=/.*[Nn]ame.*[Uu]sed.*/, ' +
      'text=/.*[Aa]lready.*[Ee]xists.*/, ' +
      '[class*="error"]:has-text(/name|duplicate/i), ' +
      '[class*="alert"]:has-text(/name|duplicate/i), ' +
      'mat-error:has-text(/name|duplicate/i)'
    ).first();
    
    await expect(duplicateError).toBeVisible({ timeout: 5000 });
    
    const errorText = await duplicateError.textContent();
    expect(errorText?.toLowerCase()).toMatch(/duplicate|already|exists|taken|used/);
    
    // expect: Form submission is prevented
    await expect(form2).toBeVisible();
    
    // expect: User is prompted to choose a different name
    // The error message should guide the user
    expect(errorText).toBeTruthy();
    
    // Now change the name to a unique value and verify it works
    await nameField2.clear();
    const newUniqueName = `${uniqueName} - Modified`;
    await nameField2.fill(newUniqueName);
    await expect(nameField2).toHaveValue(newUniqueName);
    
    // Try to submit again
    await saveButton2.click();
    await page.waitForTimeout(2000);
    
    // Should now succeed
    const successNotification2 = page.locator(
      '[class*="snack"]:has-text(/success|created/i), ' +
      '[class*="toast"]:has-text(/success|created/i), ' +
      '[class*="notification"]:has-text(/success|created/i)'
    ).first();
    
    const form2Closed = !(await form2.isVisible({ timeout: 2000 }).catch(() => false));
    const notification2Visible = await successNotification2.isVisible({ timeout: 2000 }).catch(() => false);
    
    expect(form2Closed || notification2Visible).toBe(true);
  });
});
