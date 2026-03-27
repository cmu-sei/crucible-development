// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('Create Organization', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to Organizations section
    await page.waitForLoadState('networkidle');
    
    const orgsLink = page.locator(
      'a:has-text("Organizations"), ' +
      'a:has-text("Organisations"), ' +
      'button:has-text("Organizations"), ' +
      '[routerLink*="organizations"], ' +
      '[href*="organizations"]'
    ).first();
    
    if (await orgsLink.isVisible({ timeout: 5000 })) {
      await orgsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      await page.goto(`${Services.Blueprint.UI}/organizations`);
      await page.waitForLoadState('networkidle');
    }
    
    // expect: Organizations list is visible
    const orgsList = page.locator(
      '[class*="organizations-list"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(orgsList).toBeVisible({ timeout: 5000 });
    
    // 2. Click 'Add Organization' button
    const createButton = page.locator(
      'button:has-text("Add Organization"), ' +
      'button:has-text("Create Organization"), ' +
      'button:has-text("New Organization"), ' +
      'button:has-text("Add Org"), ' +
      'button:has-text("Add"), ' +
      'button:has-text("Create")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    // expect: Organization creation form is displayed
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // 3. Enter organization details
    const nameField = page.locator(
      'input[name="name"], ' +
      'input[formControlName="name"], ' +
      'input[placeholder*="Name"], ' +
      'input[placeholder*="Organization"]'
    ).first();
    
    await expect(nameField).toBeVisible();
    await nameField.fill('Cyber Defense Organization');
    
    // expect: Name and description fields accept input
    await expect(nameField).toHaveValue('Cyber Defense Organization');
    
    const descriptionField = page.locator(
      'textarea[name="description"], ' +
      'textarea[formControlName="description"], ' +
      'input[name="description"], ' +
      'input[placeholder*="Description"]'
    ).first();
    
    if (await descriptionField.isVisible({ timeout: 2000 })) {
      await descriptionField.fill('Organization responsible for cybersecurity defense operations');
      await expect(descriptionField).toHaveValue('Organization responsible for cybersecurity defense operations');
    }
    
    // 4. Click 'Save'
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // expect: Organization is created successfully
    await page.waitForTimeout(2000);
    
    // expect: New organization appears in the list
    const notification = page.locator(
      '[class*="snack"], ' +
      '[class*="toast"], ' +
      '[class*="notification"], ' +
      'text=success, ' +
      'text=created'
    );
    await expect(notification.first()).toBeVisible({ timeout: 5000 });
    
    await page.waitForLoadState('networkidle');
    const newOrgItem = page.locator('text=Cyber Defense Organization');
    await expect(newOrgItem).toBeVisible({ timeout: 5000 });
    
    // expect: Can now be assigned to teams and used in scenario events
    console.log('Organization created successfully and is now available for team assignment');
  });
});
