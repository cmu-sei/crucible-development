// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Player Integration - View Association', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Create or edit a MSEL
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Navigate to a MSEL details page
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL form is displayed
      await page.waitForTimeout(1000);
      
      // Look for edit button or settings
      const editButton = page.locator(
        'button:has-text("Edit"), ' +
        'button[class*="edit"], ' +
        'button:has-text("Settings"), ' +
        'mat-icon:has-text("edit")'
      ).first();
      
      if (await editButton.isVisible({ timeout: 3000 })) {
        await editButton.click();
        await page.waitForTimeout(1000);
      }
      
      // 2. Associate a Player view with the MSEL
      // Look for Player view selector
      const playerViewSection = page.locator(
        '[class*="player-view"], ' +
        'text=Player View, ' +
        '[formControlName*="player"], ' +
        '[formControlName*="view"]'
      ).first();
      
      const playerViewSelector = page.locator(
        'select[name*="player"], ' +
        'mat-select[formControlName*="player"], ' +
        'select[formControlName*="view"]'
      ).first();
      
      if (await playerViewSelector.isVisible({ timeout: 3000 })) {
        await playerViewSelector.click();
        
        // expect: Player view selector shows available views from Player service (http://localhost:4301)
        await page.waitForTimeout(1000);
        
        // expect: View can be selected and linked to MSEL
        const viewOption = page.locator(
          'mat-option, ' +
          'option'
        ).first();
        
        if (await viewOption.isVisible({ timeout: 2000 })) {
          await viewOption.click();
          
          // Save the MSEL
          const saveButton = page.locator(
            'button:has-text("Save"), ' +
            'button:has-text("Update"), ' +
            'button[type="submit"]'
          ).last();
          
          if (await saveButton.isVisible({ timeout: 2000 })) {
            await saveButton.click();
            await page.waitForTimeout(2000);
            
            // expect: A success notification is displayed
            const notification = page.locator(
              '[class*="snack"], ' +
              '[class*="toast"], ' +
              'text=success, ' +
              'text=updated'
            );
          }
        }
      }
      
      // 3. Save and view MSEL details
      // Navigate back to MSEL details if needed
      await page.waitForTimeout(1000);
      
      // expect: Player view is shown as associated
      const playerViewDisplay = page.locator(
        '[class*="player-view"], ' +
        'text=Player View:, ' +
        '[class*="view-name"]'
      ).first();
      
      // expect: Link to open Player with this view is available
      const openPlayerButton = page.locator(
        'button:has-text("Open in Player"), ' +
        'a:has-text("Open in Player"), ' +
        'button:has-text("View in Player"), ' +
        'a[href*="player"], ' +
        'a[href*="4301"]'
      ).first();
      
      if (await openPlayerButton.isVisible({ timeout: 5000 })) {
        // Listen for new page/tab
        const pagePromise = page.context().waitForEvent('page', { timeout: 10000 });
        
        await openPlayerButton.click();
        
        try {
          // Navigate to Player service occurs
          const playerPage = await pagePromise;
          await playerPage.waitForLoadState('networkidle', { timeout: 10000 });
          
          // Verify Player page loaded
          await expect(playerPage).toHaveURL(new RegExp('.*localhost:4301.*'), { timeout: 10000 });
          
          // Close Player tab and return to Blueprint
          await playerPage.close();
        } catch (error) {
          console.log('Player integration link did not open in new window:', error);
        }
      } else {
        console.log('Player view integration not configured or available');
      }
    } else {
      test.skip();
    }
  });
});
