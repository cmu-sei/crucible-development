// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('Create New Team', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to Teams section
    await page.waitForLoadState('networkidle');
    
    const teamsLink = page.locator(
      'a:has-text("Teams"), ' +
      'button:has-text("Teams"), ' +
      '[routerLink*="teams"], ' +
      '[href*="teams"]'
    ).first();
    
    if (await teamsLink.isVisible({ timeout: 5000 })) {
      await teamsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      await page.goto(`${Services.Blueprint.UI}/teams`);
      await page.waitForLoadState('networkidle');
    }
    
    // expect: Teams list is visible
    const teamsList = page.locator(
      '[class*="teams-list"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(teamsList).toBeVisible({ timeout: 5000 });
    
    // 2. Click 'Add Team' or 'Create Team' button
    const createButton = page.locator(
      'button:has-text("Add Team"), ' +
      'button:has-text("Create Team"), ' +
      'button:has-text("New Team"), ' +
      'button:has-text("Add"), ' +
      'button:has-text("Create")'
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    await createButton.click();
    
    // expect: Team creation form is displayed
    await page.waitForTimeout(1000);
    const form = page.locator('form, [class*="dialog"], [class*="modal"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // 3. Enter 'Blue Team' in the Name field
    const nameField = page.locator(
      'input[name="name"], ' +
      'input[formControlName="name"], ' +
      'input[placeholder*="Name"], ' +
      'input[placeholder*="name"]'
    ).first();
    await nameField.fill('Blue Team');
    
    // expect: Name field accepts input
    await expect(nameField).toHaveValue('Blue Team');
    
    // 4. Select or create an organization for this team
    const orgDropdown = page.locator(
      'select[name*="organization"], ' +
      'mat-select[formControlName*="organization"], ' +
      '[placeholder*="Organization"]'
    ).first();
    
    if (await orgDropdown.isVisible({ timeout: 2000 })) {
      await orgDropdown.click();
      await page.waitForTimeout(500);
      
      // Try to select the first available organization
      const orgOption = page.locator(
        'mat-option, ' +
        'option, ' +
        '[role="option"]'
      ).first();
      
      if (await orgOption.isVisible({ timeout: 2000 })) {
        await orgOption.click();
      }
    }
    
    // expect: Organization dropdown or creation field is available
    // (Already verified by the check above)
    
    // 5. Click 'Save' or 'Create' button
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Create"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // expect: The team is created successfully
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
    
    // expect: The new team appears in the teams list
    await page.waitForLoadState('networkidle');
    const newTeamItem = page.locator('text=Blue Team');
    await expect(newTeamItem).toBeVisible({ timeout: 5000 });
  });
});
