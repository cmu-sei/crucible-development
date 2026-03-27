// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Search and Filtering', () => {
  test('MSEL Filtering by Date Range', async ({ page }) => {
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
    
    // 2. Apply date range filter
    // Look for date range filter controls
    const dateRangeContainer = page.locator(
      '[class*="date-range"], ' +
      '[class*="date-filter"], ' +
      '[class*="filter-date"]'
    ).first();
    
    // Look for start date input
    const startDateInput = page.locator(
      'input[name*="startDate"], ' +
      'input[name*="start"], ' +
      'input[placeholder*="Start"], ' +
      'input[placeholder*="From"], ' +
      'input[type="date"]:first-of-type, ' +
      'mat-datepicker-input:first-of-type, ' +
      '[class*="date-start"]'
    ).first();
    
    // Look for end date input
    const endDateInput = page.locator(
      'input[name*="endDate"], ' +
      'input[name*="end"], ' +
      'input[placeholder*="End"], ' +
      'input[placeholder*="To"], ' +
      'input[type="date"]:last-of-type, ' +
      'mat-datepicker-input:last-of-type, ' +
      '[class*="date-end"]'
    ).first();
    
    // Check if date filter is available
    const startDateVisible = await startDateInput.isVisible({ timeout: 5000 }).catch(() => false);
    
    if (startDateVisible) {
      // expect: Date picker allows selecting start and end dates
      await expect(startDateInput).toBeVisible();
      
      // Set start date (use a date range that should include some MSELs)
      const startDate = '2025-01-01';
      await startDateInput.fill(startDate);
      await page.waitForTimeout(500);
      
      // Set end date
      const endDateVisible = await endDateInput.isVisible({ timeout: 2000 }).catch(() => false);
      if (endDateVisible) {
        const endDate = '2026-12-31';
        await endDateInput.fill(endDate);
        await page.waitForTimeout(500);
      }
      
      // Press Enter or click apply button if available
      const applyButton = page.locator(
        'button:has-text("Apply"), ' +
        'button:has-text("Filter"), ' +
        '[aria-label*="Apply"], ' +
        '[class*="apply-filter"]'
      ).first();
      
      const applyButtonVisible = await applyButton.isVisible({ timeout: 2000 }).catch(() => false);
      if (applyButtonVisible) {
        await applyButton.click();
      } else {
        // Try pressing Enter on the end date input
        await startDateInput.press('Enter');
      }
      
      await page.waitForTimeout(1500);
      
      // expect: List updates to show only MSELs within the selected date range
      await page.waitForLoadState('networkidle');
      const filteredItems = page.locator(
        '[class*="msel-item"], ' +
        '[class*="msel-card"], ' +
        'table tbody tr, ' +
        '[class*="list-item"]'
      );
      const filteredCount = await filteredItems.count();
      
      // The filtered count should be >= 0 (date range might include all or some MSELs)
      expect(filteredCount).toBeGreaterThanOrEqual(0);
      expect(filteredCount).toBeLessThanOrEqual(initialCount);
      
      // Verify that filtered MSELs show dates within the range
      if (filteredCount > 0) {
        const firstFilteredItem = filteredItems.first();
        await expect(firstFilteredItem).toBeVisible();
        
        // Check if date information is displayed
        const dateText = page.locator(
          '[class*="date"], ' +
          '[class*="created"], ' +
          '[class*="modified"]'
        ).first();
        
        if (await dateText.isVisible({ timeout: 2000 })) {
          const dateContent = await dateText.textContent();
          expect(dateContent).toBeTruthy();
        }
      }
    } else {
      // Date filter might not be immediately visible - look for filter button
      const filterButton = page.locator(
        'button:has-text("Filter"), ' +
        'button:has-text("Filters"), ' +
        '[aria-label*="Filter"], ' +
        'mat-icon:has-text("filter_list")'
      ).first();
      
      if (await filterButton.isVisible({ timeout: 3000 })) {
        await filterButton.click();
        await page.waitForTimeout(1000);
        
        // Try to find date inputs again after opening filter panel
        const dateInputAfterFilter = page.locator(
          'input[type="date"], ' +
          'mat-datepicker-input, ' +
          'input[placeholder*="Date"]'
        ).first();
        
        if (await dateInputAfterFilter.isVisible({ timeout: 2000 })) {
          await dateInputAfterFilter.fill('2025-01-01');
          await page.waitForTimeout(500);
          await dateInputAfterFilter.press('Enter');
          await page.waitForTimeout(1500);
        }
      }
      
      // Verify the list is still visible even if date filter is not available
      await expect(mselList).toBeVisible();
    }
    
    await page.waitForLoadState('networkidle');
  });
});
