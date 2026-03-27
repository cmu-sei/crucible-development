// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('View User Details', async ({ page }) => {
    // Log in as admin user
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // 1. Navigate to Users section
    const usersLink = page.locator('text=Users, a[href*="user"], button:has-text("Users")').first();
    
    if (await usersLink.isVisible({ timeout: 3000 })) {
      await usersLink.click();
    } else {
      await page.goto(`${Services.Blueprint.UI}/admin/users`);
    }
    
    // expect: Users list is visible
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveURL(/.*user.*/, { timeout: 10000 });
    
    const usersList = page.locator('[class*="user"], table, [role="table"], [class*="list"]').first();
    await expect(usersList).toBeVisible({ timeout: 5000 });
    
    // 2. Click on a user
    // Find the first user in the list (could be a row, link, or button)
    const firstUser = page.locator('[class*="user-row"], tr, [class*="list-item"], a[href*="user/"]').first();
    await expect(firstUser).toBeVisible({ timeout: 5000 });
    
    // Get user identifier before clicking
    const userText = await firstUser.textContent();
    
    // Click on the user
    await firstUser.click();
    
    // expect: User details page is displayed
    await page.waitForLoadState('networkidle');
    
    // URL should contain user identifier or 'detail'
    await expect(page).toHaveURL(/.*user.*/, { timeout: 5000 });
    
    // expect: Shows user information, roles, and permissions
    // Look for user detail sections
    const detailsSection = page.locator('[class*="detail"], [class*="info"], [class*="profile"]').first();
    await expect(detailsSection).toBeVisible({ timeout: 5000 });
    
    // Check for user information fields
    const hasUserInfo = await page.locator('text=username, text=email, text=name').isVisible({ timeout: 3000 });
    expect(hasUserInfo).toBeTruthy();
    
    // Check for roles section
    const hasRoles = await page.locator('text=role, text=Role, [class*="role"]').isVisible({ timeout: 3000 });
    expect(hasRoles).toBeTruthy();
    
    // expect: Shows MSELs and teams the user is associated with
    // Look for associations sections
    const hasMSELs = await page.locator('text=MSEL, text=Msel, [class*="msel"]').isVisible({ timeout: 2000 });
    const hasTeams = await page.locator('text=Team, text=team, [class*="team"]').isVisible({ timeout: 2000 });
    
    // At least one association section should be visible or the page should show the user has no associations
    expect(hasMSELs || hasTeams || await page.locator('text=No MSELs, text=No Teams').isVisible()).toBeTruthy();
  });
});
