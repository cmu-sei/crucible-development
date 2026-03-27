// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('Create New MSEL', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // expect: MSELs list is visible
    await page.waitForLoadState('networkidle');
    
    // 2. Click 'Create MSEL' or 'Add New' button
    const createButton = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL"), ' +
      'button:has-text("New MSEL"), ' +
      'button:has-text("Create"), ' +
      'button:has-text("Add")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    // expect: A MSEL creation form is displayed
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // 3. Enter 'Cybersecurity Training Exercise 2026' in the Name field
    const nameField = page.locator('input[name="name"], input[formControlName="name"], input[placeholder*="Name"]').first();
    await nameField.fill('Cybersecurity Training Exercise 2026');
    
    // expect: The name field accepts input
    await expect(nameField).toHaveValue('Cybersecurity Training Exercise 2026');
    
    // 4. Enter 'Advanced threat detection and response training scenario' in the Description field
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"]'
    ).first();
    await descriptionField.fill('Advanced threat detection and response training scenario');
    
    // expect: The description field accepts input
    await expect(descriptionField).toHaveValue('Advanced threat detection and response training scenario');
    
    // 5. Set the start date and end date for the MSEL
    const startDateField = page.locator('input[name*="start"], input[placeholder*="Start"]').first();
    if (await startDateField.isVisible({ timeout: 2000 })) {
      await startDateField.fill('2026-04-01');
    }
    
    const endDateField = page.locator('input[name*="end"], input[placeholder*="End"]').first();
    if (await endDateField.isVisible({ timeout: 2000 })) {
      await endDateField.fill('2026-04-30');
    }
    
    // 6. Select or create teams/organizations to participate
    // Skip if not immediately required for MSEL creation
    
    // 7. Click 'Save' or 'Create' button
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // expect: The MSEL is created successfully
    await page.waitForTimeout(2000);
    
    // expect: A success notification is displayed
    const notification = page.locator(
      '[class*="snack"], ' +
      '[class*="toast"], ' +
      '[class*="notification"], ' +
      'text=success, ' +
      'text=created'
    );
    await expect(notification.first()).toBeVisible({ timeout: 5000 });
    
    // expect: The new MSEL appears in the MSELs list
    const newMselItem = page.locator('text=Cybersecurity Training Exercise 2026');
    await expect(newMselItem).toBeVisible({ timeout: 5000 });
    
    // expect: User is redirected to the MSEL details or edit page
    await page.waitForLoadState('networkidle');
  });
});
