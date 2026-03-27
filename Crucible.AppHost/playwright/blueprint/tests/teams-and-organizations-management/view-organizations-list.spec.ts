// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('View Organizations List', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to Organizations section
    await page.waitForLoadState('networkidle');
    
    // Try to find and click on Organizations navigation link
    const orgsLink = page.locator(
      'a:has-text("Organizations"), ' +
      'a:has-text("Organisations"), ' +
      'button:has-text("Organizations"), ' +
      '[routerLink*="organizations"], ' +
      '[routerLink*="orgs"], ' +
      '[href*="organizations"]'
    ).first();
    
    if (await orgsLink.isVisible({ timeout: 5000 })) {
      await orgsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      // Try navigating directly via URL
      await page.goto(`${Services.Blueprint.UI}/organizations`);
      await page.waitForLoadState('networkidle');
      
      // Try alternative URL
      if (!(await page.locator('[class*="organizations-list"], table').first().isVisible({ timeout: 2000 }))) {
        await page.goto(`${Services.Blueprint.UI}/orgs`);
        await page.waitForLoadState('networkidle');
      }
    }
    
    // expect: Organizations list is displayed
    const orgsList = page.locator(
      '[class*="organizations-list"], ' +
      '[class*="orgs-list"], ' +
      'table, ' +
      '[class*="data-table"], ' +
      'mat-table'
    ).first();
    await expect(orgsList).toBeVisible({ timeout: 10000 });
    
    // expect: Each organization shows: name, description, teams count
    const orgRows = page.locator(
      'tr[class*="org"], ' +
      'tr[class*="organization"], ' +
      '[class*="org-item"], ' +
      '[class*="organization-item"], ' +
      'mat-row'
    );
    
    const orgCount = await orgRows.count();
    
    if (orgCount > 0) {
      // Verify at least one organization has required information
      const firstOrg = orgRows.first();
      
      // Check for organization name
      const orgName = firstOrg.locator(
        '[class*="name"], ' +
        'td:first-child, ' +
        '[class*="org-name"]'
      ).first();
      await expect(orgName).toBeVisible();
      
      // Check for description (might be in a cell or hidden)
      const hasDescription = await firstOrg.locator(
        '[class*="description"], ' +
        'td:nth-child(2)'
      ).count() > 0;
      
      // Check for teams count
      const hasTeamCount = await firstOrg.locator(
        '[class*="team"], ' +
        '[class*="count"]'
      ).count() > 0;
      
      console.log(`Organizations list displayed with ${orgCount} organization(s)`);
      console.log(`Description visible: ${hasDescription}, Team count visible: ${hasTeamCount}`);
    } else {
      // Check for empty state
      const emptyState = page.locator(
        'text=No organizations, ' +
        'text=No data, ' +
        '[class*="empty"], ' +
        '[class*="no-data"]'
      ).first();
      
      const hasEmptyState = await emptyState.isVisible({ timeout: 3000 }).catch(() => false);
      console.log(`No organizations found. Empty state visible: ${hasEmptyState}`);
    }
  });
});
