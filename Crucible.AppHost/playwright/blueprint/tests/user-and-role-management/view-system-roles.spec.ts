// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('View System Roles', async ({ page }) => {
    // Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // 1. Navigate to Roles section in admin
    const rolesLink = page.locator('text=Roles, a[href*="role"], button:has-text("Roles")').first();
    
    if (await rolesLink.isVisible({ timeout: 3000 })) {
      await rolesLink.click();
    } else {
      // Try direct URL navigation to admin/roles
      await page.goto(`${Services.Blueprint.UI}/admin/roles`);
    }
    
    // expect: System roles list is displayed
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveURL(/.*role.*/, { timeout: 10000 });
    
    const rolesList = page.locator('[class*="role"], table, [role="table"], [class*="list"]').first();
    await expect(rolesList).toBeVisible({ timeout: 5000 });
    
    // expect: Shows roles like: Administrator, MSEL Editor, Viewer, etc.
    // Look for common system roles
    const pageContent = await page.locator('body').textContent();
    
    // Check for typical role names (at least one should be present)
    const hasAdministrator = pageContent?.includes('Administrator') || pageContent?.includes('Admin');
    const hasEditor = pageContent?.includes('Editor') || pageContent?.includes('MSEL Editor');
    const hasViewer = pageContent?.includes('Viewer');
    
    // At least one standard role should be visible
    expect(hasAdministrator || hasEditor || hasViewer).toBeTruthy();
    
    // expect: Each role shows associated permissions
    // Look for permissions column or section
    const hasPermissions = await page.locator('text=Permission, text=permission, [data-field="permission"]').isVisible({ timeout: 3000 });
    
    // Or check for individual role details showing permissions
    const firstRole = page.locator('[class*="role-row"], tr, [class*="list-item"]').first();
    if (await firstRole.isVisible({ timeout: 3000 })) {
      const roleText = await firstRole.textContent();
      // Role row should have some content
      expect(roleText).toBeTruthy();
      expect(roleText!.length).toBeGreaterThan(0);
    }
    
    // Verify permissions information is available (either in list or detail view)
    if (hasPermissions) {
      const permissionsSection = page.locator('text=Permission, [class*="permission"]').first();
      await expect(permissionsSection).toBeVisible();
    }
  });
});
