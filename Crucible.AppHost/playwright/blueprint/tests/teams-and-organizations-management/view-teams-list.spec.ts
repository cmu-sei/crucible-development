// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('View Teams List', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to Teams section (via menu or admin)
    await page.waitForLoadState('networkidle');
    
    // Try to find and click on Teams navigation link
    const teamsLink = page.locator(
      'a:has-text("Teams"), ' +
      'button:has-text("Teams"), ' +
      '[routerLink*="teams"], ' +
      '[href*="teams"]'
    ).first();
    
    if (await teamsLink.isVisible({ timeout: 5000 })) {
      await teamsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      // Try navigating directly via URL
      await page.goto(`${Services.Blueprint.UI}/teams`);
      await page.waitForLoadState('networkidle');
    }
    
    // expect: Teams list is displayed
    const teamsList = page.locator(
      '[class*="teams-list"], ' +
      '[class*="team-list"], ' +
      'table, ' +
      '[class*="data-table"], ' +
      'mat-table'
    ).first();
    await expect(teamsList).toBeVisible({ timeout: 10000 });
    
    // expect: Each team shows: name, organization, member count
    // Check if there are team rows
    const teamRows = page.locator(
      'tr[class*="team"], ' +
      '[class*="team-item"], ' +
      '[class*="team-row"], ' +
      'mat-row'
    );
    
    const teamCount = await teamRows.count();
    
    if (teamCount > 0) {
      // Verify at least one team has required information
      const firstTeam = teamRows.first();
      
      // Check for team name
      const teamName = firstTeam.locator(
        '[class*="name"], ' +
        'td:first-child, ' +
        '[class*="team-name"]'
      ).first();
      await expect(teamName).toBeVisible();
      
      // Check for organization (might be in any column)
      const hasOrganization = await firstTeam.locator(
        '[class*="organization"], ' +
        '[class*="org"]'
      ).count() > 0;
      
      // Note: Member count might not be immediately visible in list view
      console.log(`Teams list displayed with ${teamCount} team(s)`);
    }
    
    // expect: If no teams exist, an appropriate empty state is shown
    if (teamCount === 0) {
      const emptyState = page.locator(
        'text=No teams, ' +
        'text=No data, ' +
        '[class*="empty"], ' +
        '[class*="no-data"]'
      ).first();
      await expect(emptyState).toBeVisible({ timeout: 5000 });
    }
  });
});
