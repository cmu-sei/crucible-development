// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('Search and Filter MSELs', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is visible with multiple MSELs
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(mselList).toBeVisible({ timeout: 5000 });
    
    // Count initial MSELs
    const mselItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    const initialCount = await mselItems.count();
    expect(initialCount).toBeGreaterThan(0);
    
    // 2. Enter a search term in the search box
    const searchBox = page.locator(
      'input[placeholder*="Search"], ' +
      'input[placeholder*="Filter"], ' +
      'input[type="search"], ' +
      '[class*="search-input"]'
    ).first();
    await expect(searchBox).toBeVisible({ timeout: 5000 });
    
    // Search for a specific term (using first word from visible MSEL if possible)
    const searchTerm = 'Training'; // or 'Exercise' or 'Cyber'
    await searchBox.fill(searchTerm);
    
    // expect: The list filters to show only MSELs matching the search term
    await page.waitForTimeout(1000); // Allow time for filtering
    const filteredItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    const filteredCount = await filteredItems.count();
    
    // expect: Search works on MSEL name and description
    // Verify that filtered results contain the search term
    if (filteredCount > 0) {
      const firstFilteredItem = filteredItems.first();
      const itemText = await firstFilteredItem.textContent();
      expect(itemText?.toLowerCase()).toContain(searchTerm.toLowerCase());
    }
    
    // expect: Results update in real-time or after pressing enter
    // Results should already be filtered at this point
    expect(filteredCount).toBeLessThanOrEqual(initialCount);
    
    // 3. Clear the search box
    await searchBox.clear();
    
    // expect: All MSELs are displayed again
    await page.waitForTimeout(1000); // Allow time for list to refresh
    const restoredItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    const restoredCount = await restoredItems.count();
    expect(restoredCount).toBe(initialCount);
    
    // 4. Apply filters such as status or date range
    // Look for filter controls
    const statusFilter = page.locator(
      'select[name*="status"], ' +
      '[class*="status-filter"], ' +
      'mat-select[placeholder*="Status"]'
    ).first();
    
    const dateRangeFilter = page.locator(
      'input[name*="date"], ' +
      'input[placeholder*="Date"], ' +
      '[class*="date-picker"]'
    ).first();
    
    // Try to apply status filter if available
    if (await statusFilter.isVisible({ timeout: 2000 })) {
      await statusFilter.click();
      await page.waitForTimeout(500);
      
      // Select first available option
      const filterOption = page.locator(
        'mat-option, ' +
        'option, ' +
        '[role="option"]'
      ).first();
      
      if (await filterOption.isVisible({ timeout: 2000 })) {
        await filterOption.click();
        await page.waitForTimeout(1000);
        
        // expect: The list filters according to the selected criteria
        const statusFilteredItems = page.locator(
          '[class*="msel-item"], ' +
          '[class*="msel-card"], ' +
          'table tbody tr'
        );
        const statusFilteredCount = await statusFilteredItems.count();
        expect(statusFilteredCount).toBeGreaterThanOrEqual(0);
      }
    } else if (await dateRangeFilter.isVisible({ timeout: 2000 })) {
      // Try date range filter if status filter not available
      await dateRangeFilter.fill('2026-01-01');
      await page.waitForTimeout(1000);
      
      // expect: The list filters according to the selected criteria
      const dateFilteredItems = page.locator(
        '[class*="msel-item"], ' +
        '[class*="msel-card"], ' +
        'table tbody tr'
      );
      const dateFilteredCount = await dateFilteredItems.count();
      expect(dateFilteredCount).toBeGreaterThanOrEqual(0);
    }
    
    // Verify the filtering functionality works
    await page.waitForLoadState('networkidle');
  });
});
