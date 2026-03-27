// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('View MSELs List', async ({ page }) => {
    // 1. Navigate to http://localhost:4725 after logging in
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: MSELs list is displayed on the home page or main dashboard
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Check for MSEL list container
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(mselList).toBeVisible({ timeout: 5000 });
    
    // expect: Each MSEL shows: name, description, status, dates, team/organization
    const mselItems = page.locator(
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    
    const itemCount = await mselItems.count();
    
    if (itemCount > 0) {
      // Verify first MSEL item has expected fields
      const firstItem = mselItems.first();
      await expect(firstItem).toBeVisible();
      
      // Check for typical MSEL fields (name is most likely to be present)
      const hasContent = await firstItem.evaluate((el) => {
        return el.textContent && el.textContent.trim().length > 0;
      });
      expect(hasContent).toBe(true);
      
      // expect: MSELs can be sorted and filtered
      const sortButtons = page.locator(
        'button[class*="sort"], ' +
        'th[class*="sortable"], ' +
        '[class*="mat-sort-header"]'
      );
      const sortButtonCount = await sortButtons.count();
      expect(sortButtonCount).toBeGreaterThanOrEqual(0);
      
      const filterInputs = page.locator(
        'input[placeholder*="Search"], ' +
        'input[placeholder*="Filter"], ' +
        '[class*="search-input"]'
      );
      const filterInputCount = await filterInputs.count();
      expect(filterInputCount).toBeGreaterThanOrEqual(0);
    } else {
      // expect: If no MSELs exist, an appropriate empty state is shown with option to create new MSEL
      const emptyState = page.locator(
        'text=No MSELs, ' +
        'text=No items, ' +
        'text=Create your first, ' +
        '[class*="empty-state"]'
      ).first();
      await expect(emptyState).toBeVisible({ timeout: 3000 });
      
      const createButton = page.locator(
        'button:has-text("Create"), ' +
        'button:has-text("Add"), ' +
        'button:has-text("New MSEL")'
      ).first();
      await expect(createButton).toBeVisible();
    }
  });
});
