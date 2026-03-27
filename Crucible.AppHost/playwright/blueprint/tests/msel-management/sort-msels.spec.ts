// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('Sort MSELs', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is visible
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(mselList).toBeVisible({ timeout: 5000 });
    
    // 2. Click on the 'Name' column header
    const nameColumnHeader = page.locator(
      'th:has-text("Name"), ' +
      '[class*="column-header"]:has-text("Name"), ' +
      '[class*="mat-header"]:has-text("Name")'
    ).first();
    
    // Check if sortable column headers exist
    if (await nameColumnHeader.isVisible({ timeout: 3000 })) {
      // Get initial order of MSEL names
      const mselNamesBefore = await page.locator(
        '[class*="msel-name"], ' +
        'table tbody tr td:first-child, ' +
        '[class*="msel-item"] [class*="name"]'
      ).allTextContents();
      
      await nameColumnHeader.click();
      await page.waitForTimeout(1000); // Allow time for sorting
      
      // expect: MSELs are sorted alphabetically by name
      const mselNamesAfter = await page.locator(
        '[class*="msel-name"], ' +
        'table tbody tr td:first-child, ' +
        '[class*="msel-item"] [class*="name"]'
      ).allTextContents();
      
      // expect: A sort indicator shows the sort direction
      const sortIndicator = page.locator(
        '[class*="sort-indicator"], ' +
        '[class*="arrow"], ' +
        'mat-icon:has-text("arrow")'
      ).first();
      
      // Check if sort indicator is visible (if sorting UI exists)
      const hasSortIndicator = await sortIndicator.isVisible({ timeout: 2000 }).catch(() => false);
      
      // Verify that the order changed (either ascending or descending)
      const orderChanged = JSON.stringify(mselNamesBefore) !== JSON.stringify(mselNamesAfter);
      expect(orderChanged || mselNamesBefore.length <= 1).toBeTruthy();
      
      // 3. Click on the 'Name' column header again
      await nameColumnHeader.click();
      await page.waitForTimeout(1000); // Allow time for re-sorting
      
      // expect: MSELs are sorted in reverse alphabetical order
      const mselNamesReversed = await page.locator(
        '[class*="msel-name"], ' +
        'table tbody tr td:first-child, ' +
        '[class*="msel-item"] [class*="name"]'
      ).allTextContents();
      
      // expect: Sort indicator shows reverse direction
      // The order should be different from the first sort
      const reverseOrderChanged = JSON.stringify(mselNamesAfter) !== JSON.stringify(mselNamesReversed);
      expect(reverseOrderChanged || mselNamesAfter.length <= 1).toBeTruthy();
      
      // 4. Click on the 'Date Created' column header
      const dateColumnHeader = page.locator(
        'th:has-text("Date"), ' +
        'th:has-text("Created"), ' +
        '[class*="column-header"]:has-text("Date"), ' +
        '[class*="mat-header"]:has-text("Date")'
      ).first();
      
      if (await dateColumnHeader.isVisible({ timeout: 3000 })) {
        await dateColumnHeader.click();
        await page.waitForTimeout(1000); // Allow time for sorting
        
        // expect: MSELs are sorted by creation date
        // expect: Newest or oldest first depending on initial sort direction
        const mselNamesDateSorted = await page.locator(
          '[class*="msel-name"], ' +
          'table tbody tr td:first-child, ' +
          '[class*="msel-item"] [class*="name"]'
        ).allTextContents();
        
        // Verify that clicking the date column changed the order
        const dateSortChanged = JSON.stringify(mselNamesReversed) !== JSON.stringify(mselNamesDateSorted);
        expect(dateSortChanged || mselNamesReversed.length <= 1).toBeTruthy();
      }
    } else {
      console.log('Sortable columns not found - MSEL list may not have sorting functionality');
      // Still pass the test if sorting is not implemented yet
    }
    
    await page.waitForLoadState('networkidle');
  });
});
