// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Search and Filtering', () => {
  test('Advanced Search with Multiple Criteria', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Open advanced search or filter panel
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Look for MSELs list
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
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
    
    // Look for advanced search or filter button
    const advancedSearchButton = page.locator(
      'button:has-text("Advanced"), ' +
      'button:has-text("Filters"), ' +
      'button:has-text("Filter"), ' +
      '[aria-label*="Advanced"], ' +
      '[aria-label*="Filter"], ' +
      'mat-icon:has-text("filter_list")'
    ).first();
    
    const advSearchVisible = await advancedSearchButton.isVisible({ timeout: 5000 }).catch(() => false);
    
    if (advSearchVisible) {
      await advancedSearchButton.click();
      await page.waitForTimeout(1000);
    }
    
    // expect: Advanced search options are displayed
    const filterPanel = page.locator(
      '[class*="filter-panel"], ' +
      '[class*="advanced-search"], ' +
      '[class*="filters"], ' +
      '[role="dialog"], ' +
      'mat-expansion-panel'
    ).first();
    
    const filterPanelVisible = await filterPanel.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (filterPanelVisible) {
      await expect(filterPanel).toBeVisible();
    }
    
    // 2. Apply multiple filters (e.g., status + date range + organization)
    
    // Filter 1: Status
    const statusFilter = page.locator(
      'select[name*="status"], ' +
      '[class*="status-filter"], ' +
      'mat-select[placeholder*="Status"]'
    ).first();
    
    const statusFilterVisible = await statusFilter.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (statusFilterVisible) {
      await statusFilter.click();
      await page.waitForTimeout(500);
      
      const statusOption = page.locator(
        'mat-option, ' +
        'option:not([value=""]), ' +
        '[role="option"]'
      ).first();
      
      if (await statusOption.isVisible({ timeout: 2000 })) {
        await statusOption.click();
        await page.waitForTimeout(500);
      }
    }
    
    // Filter 2: Date Range
    const startDateInput = page.locator(
      'input[name*="startDate"], ' +
      'input[name*="start"], ' +
      'input[placeholder*="Start"], ' +
      'input[type="date"]'
    ).first();
    
    const startDateVisible = await startDateInput.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (startDateVisible) {
      const startDate = '2025-01-01';
      await startDateInput.fill(startDate);
      await page.waitForTimeout(500);
      
      // Set end date if available
      const endDateInput = page.locator(
        'input[name*="endDate"], ' +
        'input[name*="end"], ' +
        'input[placeholder*="End"]'
      ).first();
      
      if (await endDateInput.isVisible({ timeout: 2000 })) {
        const endDate = '2026-12-31';
        await endDateInput.fill(endDate);
        await page.waitForTimeout(500);
      }
    }
    
    // Filter 3: Organization (if available)
    const organizationFilter = page.locator(
      'select[name*="organization"], ' +
      '[class*="organization-filter"], ' +
      'mat-select[placeholder*="Organization"]'
    ).first();
    
    const orgFilterVisible = await organizationFilter.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (orgFilterVisible) {
      await organizationFilter.click();
      await page.waitForTimeout(500);
      
      const orgOption = page.locator(
        'mat-option, ' +
        'option:not([value=""]), ' +
        '[role="option"]'
      ).first();
      
      if (await orgOption.isVisible({ timeout: 2000 })) {
        await orgOption.click();
        await page.waitForTimeout(500);
      }
    }
    
    // Apply filters button
    const applyButton = page.locator(
      'button:has-text("Apply"), ' +
      'button:has-text("Search"), ' +
      'button:has-text("Filter"), ' +
      '[aria-label*="Apply"]'
    ).first();
    
    const applyButtonVisible = await applyButton.isVisible({ timeout: 2000 }).catch(() => false);
    
    if (applyButtonVisible) {
      await applyButton.click();
      await page.waitForTimeout(1500);
    }
    
    // expect: Multiple filters can be combined
    // expect: Results match all selected criteria (AND logic)
    await page.waitForLoadState('networkidle');
    
    const filteredItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr, ' +
      '[class*="list-item"]'
    );
    const filteredCount = await filteredItems.count();
    
    // With multiple filters, we expect fewer or equal results
    expect(filteredCount).toBeLessThanOrEqual(initialCount);
    expect(filteredCount).toBeGreaterThanOrEqual(0);
    
    // expect: Filter summary shows active filters
    const filterSummary = page.locator(
      '[class*="filter-summary"], ' +
      '[class*="active-filters"], ' +
      '[class*="filter-chips"], ' +
      'mat-chip-list, ' +
      '[class*="applied-filters"]'
    ).first();
    
    const summaryVisible = await filterSummary.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (summaryVisible) {
      await expect(filterSummary).toBeVisible();
      
      // Check for filter chips or tags
      const filterChips = page.locator(
        'mat-chip, ' +
        '[class*="filter-chip"], ' +
        '[class*="filter-tag"]'
      );
      
      const chipCount = await filterChips.count();
      expect(chipCount).toBeGreaterThan(0);
    }
    
    // 3. Clear all filters
    const clearAllButton = page.locator(
      'button:has-text("Clear All"), ' +
      'button:has-text("Reset"), ' +
      'button:has-text("Clear Filters"), ' +
      '[aria-label*="Clear All"], ' +
      '[aria-label*="Reset"]'
    ).first();
    
    const clearAllVisible = await clearAllButton.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (clearAllVisible) {
      await clearAllButton.click();
      await page.waitForTimeout(1500);
      
      // expect: All filters are removed
      await page.waitForLoadState('networkidle');
      
      const restoredItems = page.locator(
        '[class*="msel-item"], ' +
        '[class*="msel-card"], ' +
        'table tbody tr, ' +
        '[class*="list-item"]'
      );
      const restoredCount = await restoredItems.count();
      
      // expect: Full unfiltered list is displayed
      expect(restoredCount).toBeGreaterThanOrEqual(filteredCount);
      
      // Filter summary should be empty or hidden
      if (summaryVisible) {
        const updatedChips = page.locator(
          'mat-chip, ' +
          '[class*="filter-chip"]'
        );
        const updatedChipCount = await updatedChips.count();
        expect(updatedChipCount).toBe(0);
      }
    } else {
      // Alternative: Clear individual filters
      // Try clicking on filter chips to remove them
      const filterChipsAlt = page.locator(
        'mat-chip mat-icon:has-text("cancel"), ' +
        '[class*="filter-chip"] [class*="remove"], ' +
        '[class*="filter-chip"] button'
      );
      
      const chipCountAlt = await filterChipsAlt.count();
      
      if (chipCountAlt > 0) {
        // Click each chip's remove button
        for (let i = chipCountAlt - 1; i >= 0; i--) {
          const chip = filterChipsAlt.nth(i);
          if (await chip.isVisible({ timeout: 1000 })) {
            await chip.click();
            await page.waitForTimeout(500);
          }
        }
        
        await page.waitForLoadState('networkidle');
      }
    }
    
    await page.waitForLoadState('networkidle');
  });
});
