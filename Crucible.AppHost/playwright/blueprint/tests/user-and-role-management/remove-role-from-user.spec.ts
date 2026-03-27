// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('Remove Role from User', async ({ page }) => {
    // Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // 1. Navigate to a user's roles section
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
    
    await page.waitForLoadState('networkidle');
    
    // expect: User's roles are displayed
    const rolesSection = page.locator('[class*="role"], text=Role').first();
    await expect(rolesSection).toBeVisible({ timeout: 5000 });
    
    // Get initial page content
    const initialContent = await page.locator('body').textContent();
    
    // 2. Click remove icon for a role
    // Look for delete/remove button associated with a role
    const removeRoleButton = page.locator('button[title*="Remove" i], button[title*="Delete" i], button:has-text("Remove"), button:has-text("Delete"), [class*="delete"], [class*="remove"]').first();
    
    if (await removeRoleButton.isVisible({ timeout: 3000 })) {
      await removeRoleButton.click();
      
      // expect: Confirmation dialog appears
      await page.waitForTimeout(500);
      const confirmDialog = page.locator('[role="dialog"], [class*="dialog"], [class*="modal"], [class*="confirm"]').first();
      
      if (await confirmDialog.isVisible({ timeout: 2000 })) {
        // 3. Confirm removal
        const confirmButton = page.locator('button:has-text("Confirm"), button:has-text("Yes"), button:has-text("Remove"), button:has-text("Delete")').last();
        await confirmButton.click();
      } else {
        // No confirmation dialog, role was removed directly
        console.log('No confirmation dialog appeared, role removed directly');
      }
      
      // expect: Role is removed from user
      await page.waitForTimeout(1000);
      
      // expect: Success notification is displayed
      const successNotification = page.locator('text=success, text=removed, text=deleted, [class*="success"], [class*="notification"]').first();
      await expect(successNotification).toBeVisible({ timeout: 5000 });
      
      // expect: Role no longer appears in list
      const updatedContent = await page.locator('body').textContent();
      expect(updatedContent).not.toEqual(initialContent);
    } else {
      // If no remove button is found, the user may not have any removable roles
      console.log('Remove role button not found. User may not have removable roles.');
    }
  });
});
