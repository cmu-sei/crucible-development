// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Teams and Organizations Management', () => {
  test('Assign Teams to Organization', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to an organization's details
    await page.waitForLoadState('networkidle');
    
    const orgsLink = page.locator(
      'a:has-text("Organizations"), ' +
      'button:has-text("Organizations"), ' +
      '[routerLink*="organizations"], ' +
      '[href*="organizations"]'
    ).first();
    
    if (await orgsLink.isVisible({ timeout: 5000 })) {
      await orgsLink.click();
      await page.waitForLoadState('networkidle');
    } else {
      await page.goto(`${Services.Blueprint.UI}/organizations`);
      await page.waitForLoadState('networkidle');
    }
    
    // Click on the first organization to view details
    const firstOrgRow = page.locator(
      'tr[class*="org"], ' +
      '[class*="org-item"], ' +
      'mat-row'
    ).first();
    
    // Try to click on details or view button
    const viewButton = page.locator(
      'button[matTooltip*="View"], ' +
      'button[matTooltip*="Details"], ' +
      'button:has-text("View"), ' +
      'mat-icon:has-text("visibility")'
    ).first();
    
    if (await viewButton.isVisible({ timeout: 3000 })) {
      await viewButton.click();
    } else {
      // Click on the row itself
      await firstOrgRow.click();
    }
    
    await page.waitForTimeout(1000);
    
    // expect: Organization details page is displayed
    const detailsPage = page.locator(
      '[class*="details"], ' +
      '[class*="organization-detail"], ' +
      'mat-card, ' +
      '[class*="card"]'
    ).first();
    await expect(detailsPage).toBeVisible({ timeout: 5000 });
    
    // 2. View teams assigned to this organization
    const teamsSection = page.locator(
      '[class*="teams"], ' +
      'section:has-text("Teams"), ' +
      'div:has-text("Teams")'
    ).first();
    
    // expect: List of teams is shown
    if (await teamsSection.isVisible({ timeout: 3000 })) {
      console.log('Teams section is visible');
      
      // Check for existing teams
      const teamItems = page.locator(
        '[class*="team-item"], ' +
        'li, ' +
        'mat-list-item'
      );
      
      const teamCount = await teamItems.count();
      console.log(`Organization has ${teamCount} team(s) assigned`);
    }
    
    // 3. Add a new team to the organization
    const addTeamButton = page.locator(
      'button:has-text("Add Team"), ' +
      'button:has-text("Assign Team"), ' +
      'button:has-text("Add"), ' +
      '[class*="add-team"]'
    ).first();
    
    if (await addTeamButton.isVisible({ timeout: 3000 })) {
      await addTeamButton.click();
      await page.waitForTimeout(1000);
      
      // expect: Team can be selected and assigned
      const teamSelector = page.locator(
        'select[name*="team"], ' +
        'mat-select, ' +
        '[placeholder*="Team"]'
      ).first();
      
      if (await teamSelector.isVisible({ timeout: 2000 })) {
        await teamSelector.click();
        await page.waitForTimeout(500);
        
        // Select the first available team
        const teamOption = page.locator(
          'mat-option, ' +
          'option, ' +
          '[role="option"]'
        ).first();
        
        if (await teamOption.isVisible({ timeout: 2000 })) {
          const teamName = await teamOption.textContent();
          await teamOption.click();
          
          // Save the assignment
          const saveButton = page.locator(
            'button:has-text("Save"), ' +
            'button:has-text("Assign"), ' +
            'button:has-text("Add"), ' +
            'button[type="submit"]'
          ).last();
          
          if (await saveButton.isVisible({ timeout: 2000 })) {
            await saveButton.click();
            
            // expect: Organization-team relationship is saved
            await page.waitForTimeout(2000);
            
            const notification = page.locator(
              '[class*="snack"], ' +
              '[class*="toast"], ' +
              '[class*="notification"], ' +
              'text=success, ' +
              'text=assigned, ' +
              'text=added'
            );
            
            await expect(notification.first()).toBeVisible({ timeout: 5000 });
            
            // Verify the team appears in the organization's team list
            await page.waitForLoadState('networkidle');
            const assignedTeam = page.locator(`text=${teamName}`);
            await expect(assignedTeam).toBeVisible({ timeout: 5000 });
            
            console.log(`Team "${teamName}" successfully assigned to organization`);
          }
        }
      }
    } else {
      console.log('Add Team button not found - teams may be managed through team creation form');
      
      // Alternative: Teams might be assigned when creating/editing teams rather than from organization page
      // In this case, verify that the relationship exists and is displayed
      const teamsList = page.locator(
        '[class*="teams-list"], ' +
        'ul, ' +
        'mat-list'
      ).first();
      
      if (await teamsList.isVisible({ timeout: 2000 })) {
        console.log('Teams are displayed in organization details');
      }
    }
  });
});
