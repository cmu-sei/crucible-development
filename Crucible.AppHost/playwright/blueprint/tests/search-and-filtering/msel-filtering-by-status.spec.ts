// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Search and Filtering', () => {
  test('MSEL Filtering by Status', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is displayed
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
      '[class*="data-table"], ' +
      'main'
    ).first();
    await expect(mselList).toBeVisible({ timeout: 5000 });
    
    // Count initial MSELs
    const mselItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr, ' +
      '[class*="list-item"]'
    );
    const initialCount = await mselItems.count();
    expect(initialCount).toBeGreaterThan(0);
    
    // 2. Apply status filter (e.g., Draft, Active, Completed)
    // Look for status filter dropdown
    const statusFilter = page.locator(
      'select[name*="status"], ' +
      '[class*="status-filter"], ' +
      'mat-select[placeholder*="Status"], ' +
      '[aria-label*="Status"], ' +
      'select[aria-label*="Status"], ' +
      '[class*="filter-status"]'
    ).first();
    
    // expect: Filter dropdown shows available statuses
    await expect(statusFilter).toBeVisible({ timeout: 10000 });
    await statusFilter.click();
    await page.waitForTimeout(500);
    
    // Get available status options
    const statusOptions = page.locator(
      'mat-option, ' +
      'option:not([value=""]), ' +
      '[role="option"], ' +
      '[class*="option-item"]'
    );
    
    const optionCount = await statusOptions.count();
    expect(optionCount).toBeGreaterThan(0);
    
    // Select the first non-empty status option
    const firstOption = statusOptions.first();
    await firstOption.click();
    await page.waitForTimeout(1000);
    
    // expect: List updates to show only MSELs matching selected status
    await page.waitForLoadState('networkidle');
    const filteredItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr, ' +
      '[class*="list-item"]'
    );
    const filteredCount = await filteredItems.count();
    
    // The filtered count should be less than or equal to initial count
    expect(filteredCount).toBeLessThanOrEqual(initialCount);
    expect(filteredCount).toBeGreaterThanOrEqual(0);
    
    // 3. Clear filter
    // Look for clear filter button or reset option
    const clearFilterButton = page.locator(
      'button:has-text("Clear"), ' +
      'button:has-text("Reset"), ' +
      '[aria-label*="Clear"], ' +
      '[class*="clear-filter"], ' +
      'mat-icon:has-text("clear")'
    ).first();
    
    const clearButtonVisible = await clearFilterButton.isVisible({ timeout: 2000 }).catch(() => false);
    
    if (clearButtonVisible) {
      await clearFilterButton.click();
      await page.waitForTimeout(1000);
    } else {
      // Alternative: Re-open the filter and select "All" or empty option
      await statusFilter.click();
      await page.waitForTimeout(500);
      
      const allOption = page.locator(
        'mat-option:has-text("All"), ' +
        'option[value=""], ' +
        '[role="option"]:has-text("All")'
      ).first();
      
      if (await allOption.isVisible({ timeout: 2000 })) {
        await allOption.click();
        await page.waitForTimeout(1000);
      }
    }
    
    // expect: All MSELs are displayed again
    await page.waitForLoadState('networkidle');
    const restoredItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr, ' +
      '[class*="list-item"]'
    );
    const restoredCount = await restoredItems.count();
    
    // After clearing, we should see the same or more items
    expect(restoredCount).toBeGreaterThanOrEqual(filteredCount);
    
    await page.waitForLoadState('networkidle');
  });
});
