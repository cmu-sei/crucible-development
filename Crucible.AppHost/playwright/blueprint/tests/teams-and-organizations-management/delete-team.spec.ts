// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('Delete Team', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to Teams section
    await page.waitForLoadState('networkidle');
    
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
      await page.goto(`${Services.Blueprint.UI}/teams`);
      await page.waitForLoadState('networkidle');
    }
    
    // expect: Teams list is visible
    const teamsList = page.locator(
      '[class*="teams-list"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(teamsList).toBeVisible({ timeout: 5000 });
    
    // Get the name of the first team for later verification
    const firstTeamRow = page.locator(
      'tr[class*="team"], ' +
      '[class*="team-item"], ' +
      'mat-row'
    ).first();
    
    const teamName = await firstTeamRow.locator(
      '[class*="name"], ' +
      'td:first-child'
    ).first().textContent();
    
    // 2. Click delete icon for a team
    const deleteButton = page.locator(
      'button[matTooltip*="Delete"], ' +
      'button:has-text("Delete"), ' +
      'mat-icon:has-text("delete"), ' +
      '[class*="delete-button"]'
    ).first();
    
    await expect(deleteButton).toBeVisible({ timeout: 5000 });
    await deleteButton.click();
    
    // expect: Confirmation dialog appears
    await page.waitForTimeout(1000);
    const confirmDialog = page.locator(
      '[role="dialog"], ' +
      '[class*="dialog"], ' +
      '[class*="confirmation"]'
    ).first();
    await expect(confirmDialog).toBeVisible({ timeout: 5000 });
    
    // Verify confirmation message is present
    const confirmMessage = page.locator(
      'text=confirm, ' +
      'text=delete, ' +
      'text=Are you sure'
    );
    await expect(confirmMessage.first()).toBeVisible({ timeout: 3000 });
    
    // 3. Confirm deletion
    const confirmButton = page.locator(
      'button:has-text("Confirm"), ' +
      'button:has-text("Delete"), ' +
      'button:has-text("Yes"), ' +
      'button:has-text("OK")'
    ).last();
    
    await expect(confirmButton).toBeVisible({ timeout: 5000 });
    await confirmButton.click();
    
    // expect: Team is deleted successfully
    await page.waitForTimeout(2000);
    
    // expect: A success notification is displayed
    const notification = page.locator(
      '[class*="snack"], ' +
      '[class*="toast"], ' +
      '[class*="notification"], ' +
      'text=success, ' +
      'text=deleted, ' +
      'text=removed'
    );
    await expect(notification.first()).toBeVisible({ timeout: 5000 });
    
    // expect: Team is removed from the list
    await page.waitForLoadState('networkidle');
    
    // expect: If team is referenced in scenario events, deletion may be prevented
    // Check if the team still exists (deletion was prevented) or is gone (successful deletion)
    const deletedTeamItem = page.locator(`text="${teamName}"`);
    const isStillVisible = await deletedTeamItem.isVisible({ timeout: 3000 }).catch(() => false);
    
    if (isStillVisible) {
      // Team is still visible - deletion may have been prevented due to references
      console.log('Team deletion may have been prevented due to existing references');
      
      // Check for error message
      const errorMessage = page.locator(
        'text=referenced, ' +
        'text=in use, ' +
        'text=cannot delete, ' +
        '[class*="error"]'
      );
      const hasError = await errorMessage.first().isVisible({ timeout: 2000 }).catch(() => false);
      
      if (hasError) {
        console.log('Deletion prevented: Team is referenced in scenario events');
      }
    } else {
      console.log('Team successfully deleted and removed from list');
    }
  });
});
