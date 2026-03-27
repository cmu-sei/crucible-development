// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('Edit Team', async ({ page }) => {
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
    
    // 2. Click on a team to view details or edit
    // Try to find an edit button or click on a team row
    const editButton = page.locator(
      'button[matTooltip*="Edit"], ' +
      'button:has-text("Edit"), ' +
      'mat-icon:has-text("edit"), ' +
      '[class*="edit-button"]'
    ).first();
    
    if (await editButton.isVisible({ timeout: 3000 })) {
      await editButton.click();
    } else {
      // Try clicking on the first team row
      const teamRow = page.locator(
        'tr[class*="team"], ' +
        '[class*="team-item"], ' +
        'mat-row'
      ).first();
      
      if (await teamRow.isVisible({ timeout: 3000 })) {
        await teamRow.click();
      }
    }
    
    await page.waitForTimeout(1000);
    
    // expect: Team edit form is displayed
    const form = page.locator('form, [class*="dialog"], [class*="modal"], [class*="edit"]').first();
    await expect(form).toBeVisible({ timeout: 5000 });
    
    // expect: Fields are populated with current values
    const nameField = page.locator(
      'input[name="name"], ' +
      'input[formControlName="name"], ' +
      'input[placeholder*="Name"]'
    ).first();
    await expect(nameField).toBeVisible();
    
    const currentValue = await nameField.inputValue();
    expect(currentValue.length).toBeGreaterThan(0);
    
    // 3. Modify the team name or organization
    const newName = `${currentValue} - Modified`;
    await nameField.fill(newName);
    
    // expect: Changes can be made
    await expect(nameField).toHaveValue(newName);
    
    // Try to modify organization if dropdown is available
    const orgDropdown = page.locator(
      'select[name*="organization"], ' +
      'mat-select[formControlName*="organization"]'
    ).first();
    
    if (await orgDropdown.isVisible({ timeout: 2000 })) {
      await orgDropdown.click();
      await page.waitForTimeout(500);
      
      // Select a different organization option if available
      const orgOptions = page.locator('mat-option, option');
      const optionCount = await orgOptions.count();
      
      if (optionCount > 1) {
        await orgOptions.nth(1).click();
      } else if (optionCount === 1) {
        await orgOptions.first().click();
      }
    }
    
    // 4. Click 'Save' button
    const saveButton = page.locator(
      'button:has-text("Save"), ' +
      'button:has-text("Update"), ' +
      'button[type="submit"]'
    ).last();
    await saveButton.click();
    
    // expect: Team is updated successfully
    await page.waitForTimeout(2000);
    
    // expect: A success notification is displayed
    const notification = page.locator(
      '[class*="snack"], ' +
      '[class*="toast"], ' +
      '[class*="notification"], ' +
      'text=success, ' +
      'text=updated'
    );
    await expect(notification.first()).toBeVisible({ timeout: 5000 });
    
    // expect: Updated values are reflected in the list
    await page.waitForLoadState('networkidle');
    const updatedTeamItem = page.locator(`text=${newName}`);
    await expect(updatedTeamItem).toBeVisible({ timeout: 5000 });
  });
});
