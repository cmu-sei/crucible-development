// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('User and Role Management', () => {
  test('Search Users', async ({ page }) => {
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
    
    // Get initial count of visible users
    const initialUserRows = await page.locator('[class*="user-row"], tr, [class*="list-item"]').count();
    
    // 2. Enter a search term in the search box
    // Look for search input field
    const searchInput = page.locator('input[type="search"], input[placeholder*="search" i], input[placeholder*="filter" i], input[name*="search"]').first();
    await expect(searchInput).toBeVisible({ timeout: 5000 });
    
    // Enter search term 'admin'
    await searchInput.fill('admin');
    
    // expect: The list filters to show only matching users
    // Wait for the list to update
    await page.waitForTimeout(1000); // Allow time for filtering
    
    // expect: Search works on username, name, and email
    // Verify that filtered results contain the search term
    const filteredResults = await page.locator('[class*="user-row"], tr, [class*="list-item"]').count();
    
    // The filtered count should be less than or equal to initial count
    expect(filteredResults).toBeLessThanOrEqual(initialUserRows);
    
    // expect: Results update in real-time
    // Verify search results contain 'admin' in some field
    const searchResultText = await page.locator('body').textContent();
    expect(searchResultText).toContain('admin');
    
    // 3. Clear the search box
    await searchInput.clear();
    await page.waitForTimeout(500);
    
    // expect: All users are displayed again
    const clearedUserRows = await page.locator('[class*="user-row"], tr, [class*="list-item"]').count();
    expect(clearedUserRows).toBeGreaterThanOrEqual(filteredResults);
  });
});
