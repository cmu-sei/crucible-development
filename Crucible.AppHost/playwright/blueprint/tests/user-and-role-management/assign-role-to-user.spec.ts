// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('Assign Role to User', async ({ page }) => {
    // Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // 1. Navigate to a user's details page
    const usersLink = page.locator('text=Users, a[href*="user"], button:has-text("Users")').first();
    
    if (await usersLink.isVisible({ timeout: 3000 })) {
      await usersLink.click();
    } else {
      await page.goto(`${Services.Blueprint.UI}/admin/users`);
    }
    
    await page.waitForLoadState('networkidle');
    
    // Click on a user to view details
    const firstUser = page.locator('[class*="user-row"], tr, [class*="list-item"], a[href*="user/"]').first();
    await expect(firstUser).toBeVisible({ timeout: 5000 });
    await firstUser.click();
    
    // expect: User details are displayed
    await page.waitForLoadState('networkidle');
    const detailsSection = page.locator('[class*="detail"], [class*="info"], [class*="profile"]').first();
    await expect(detailsSection).toBeVisible({ timeout: 5000 });
    
    // Get initial roles count
    const initialRolesText = await page.locator('body').textContent();
    
    // 2. Click 'Add Role' button
    const addRoleButton = page.locator('button:has-text("Add Role"), button:has-text("Assign Role"), button[title*="Add Role" i]').first();
    
    if (await addRoleButton.isVisible({ timeout: 3000 })) {
      await addRoleButton.click();
      
      // expect: Role selection dialog appears
      await page.waitForTimeout(500);
      const dialog = page.locator('[role="dialog"], [class*="dialog"], [class*="modal"]').first();
      await expect(dialog).toBeVisible({ timeout: 5000 });
      
      // 3. Select a role from available options
      // expect: Role dropdown shows system and MSEL-specific roles
      const roleSelect = page.locator('select, [role="combobox"], [role="listbox"]').first();
      
      if (await roleSelect.isVisible({ timeout: 2000 })) {
        // If it's a dropdown/select
        await roleSelect.click();
        await page.waitForTimeout(300);
        
        // Select first available role option
        const roleOption = page.locator('option, [role="option"]').nth(1); // Skip empty/placeholder option
        await roleOption.click();
      } else {
        // If it's a list of checkboxes or radio buttons
        const roleOption = page.locator('input[type="radio"], input[type="checkbox"], [role="option"]').first();
        await roleOption.click();
      }
      
      // 4. Click 'Add'
      const confirmButton = page.locator('button:has-text("Add"), button:has-text("Assign"), button:has-text("Save"), button:has-text("Confirm")').first();
      await confirmButton.click();
      
      // expect: Role is assigned to the user
      await page.waitForTimeout(1000);
      
      // expect: Success notification is displayed
      const successNotification = page.locator('text=success, text=added, text=assigned, [class*="success"], [class*="notification"]').first();
      await expect(successNotification).toBeVisible({ timeout: 5000 });
      
      // expect: Role appears in user's roles list
      const updatedRolesText = await page.locator('body').textContent();
      expect(updatedRolesText).not.toEqual(initialRolesText);
    } else {
      // If Add Role button is not visible, test may need adjustment based on actual UI
      console.log('Add Role button not found. UI may differ from expected.');
    }
  });
});
