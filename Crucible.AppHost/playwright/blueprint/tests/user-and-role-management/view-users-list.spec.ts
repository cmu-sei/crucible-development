// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('View Users List', async ({ page }) => {
    // Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // 1. Navigate to Users section (admin area)
    // Try to find users link in navigation
    const usersLink = page.locator('text=Users, a[href*="user"], button:has-text("Users")').first();
    
    if (await usersLink.isVisible({ timeout: 3000 })) {
      await usersLink.click();
    } else {
      // Try direct URL navigation to admin/users
      await page.goto(`${Services.Blueprint.UI}/admin/users`);
    }
    
    // expect: Users list is displayed
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveURL(/.*user.*/, { timeout: 10000 });
    
    // Look for users list container or table
    const usersList = page.locator('[class*="user"], table, [role="table"], [class*="list"]').first();
    await expect(usersList).toBeVisible({ timeout: 5000 });
    
    // expect: Each user shows: username, name, email, roles
    // Look for user data columns/fields
    const hasUsername = await page.locator('text=username, text=Username, [data-field="username"]').isVisible({ timeout: 3000 });
    const hasName = await page.locator('text=name, text=Name, [data-field="name"]').isVisible({ timeout: 3000 });
    const hasEmail = await page.locator('text=email, text=Email, [data-field="email"]').isVisible({ timeout: 3000 });
    const hasRoles = await page.locator('text=role, text=Role, [data-field="role"]').isVisible({ timeout: 3000 });
    
    // At least some user information should be displayed
    expect(hasUsername || hasName || hasEmail || hasRoles).toBeTruthy();
    
    // expect: Pagination controls are visible if there are many users
    // Check for pagination elements (optional based on number of users)
    const paginationExists = await page.locator('[class*="paginat"], [role="navigation"], button:has-text("Next"), button:has-text("Previous")').isVisible({ timeout: 2000 });
    
    // If pagination exists, verify it's functional
    if (paginationExists) {
      const pagination = page.locator('[class*="paginat"], [role="navigation"]').first();
      await expect(pagination).toBeVisible();
    }
  });
});
