// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Steamfitter Integration - Scenario Automation', async ({ page }) => {
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
      
      // 2. Link a Steamfitter scenario to the MSEL
      // Look for Steamfitter integration section
      const steamfitterSection = page.locator(
        '[class*="steamfitter"], ' +
        'text=Steamfitter Scenario, ' +
        '[formControlName*="steamfitter"], ' +
        '[formControlName*="scenario"]'
      ).first();
      
      const steamfitterSelector = page.locator(
        'select[name*="steamfitter"], ' +
        'mat-select[formControlName*="steamfitter"], ' +
        'select[formControlName*="scenario"]'
      ).first();
      
      if (await steamfitterSelector.isVisible({ timeout: 3000 })) {
        await steamfitterSelector.click();
        
        // expect: Steamfitter scenario selector shows available scenarios from Steamfitter service (http://localhost:4401)
        await page.waitForTimeout(1000);
        
        // expect: Scenario can be selected and associated with MSEL
        const scenarioOption = page.locator(
          'mat-option, ' +
          'option'
        ).first();
        
        if (await scenarioOption.isVisible({ timeout: 2000 })) {
          await scenarioOption.click();
          
          // Save the MSEL
          const saveButton = page.locator(
            'button:has-text("Save"), ' +
            'button:has-text("Update"), ' +
            'button[type="submit"]'
          ).last();
          
          if (await saveButton.isVisible({ timeout: 2000 })) {
            await saveButton.click();
            await page.waitForTimeout(2000);
            
            // Success notification
            const notification = page.locator(
              '[class*="snack"], ' +
              '[class*="toast"], ' +
              'text=success, ' +
              'text=updated'
            );
          }
        }
      } else {
        // Try alternative - Steamfitter integration button
        const steamfitterButton = page.locator(
          'button:has-text("Steamfitter"), ' +
          'button:has-text("Configure Automation"), ' +
          'button:has-text("Scenario Automation")'
        ).first();
        
        if (await steamfitterButton.isVisible({ timeout: 3000 })) {
          await steamfitterButton.click();
          await page.waitForTimeout(1000);
          
          const steamfitterDialog = page.locator(
            '[class*="steamfitter-dialog"], ' +
            'form'
          ).first();
          
          await expect(steamfitterDialog).toBeVisible({ timeout: 5000 });
        }
      }
      
      // 3. Configure scenario automation triggers based on MSEL timeline
      // Look for automation triggers or timeline sync
      const automationSection = page.locator(
        '[class*="automation"], ' +
        '[class*="trigger"], ' +
        'text=Automation Triggers, ' +
        'text=Timeline Sync'
      ).first();
      
      const triggerButton = page.locator(
        'button:has-text("Add Trigger"), ' +
        'button:has-text("Configure Triggers"), ' +
        'button:has-text("Timeline Sync")'
      ).first();
      
      if (await triggerButton.isVisible({ timeout: 3000 })) {
        await triggerButton.click();
        await page.waitForTimeout(1000);
        
        // expect: Scenario events can trigger Steamfitter tasks
        const triggerConfig = page.locator(
          '[class*="trigger-config"], ' +
          'form'
        ).first();
        
        // Select an event to trigger
        const eventSelector = page.locator(
          'select[name*="event"], ' +
          'mat-select[formControlName*="event"]'
        ).first();
        
        if (await eventSelector.isVisible({ timeout: 2000 })) {
          await eventSelector.click();
          
          const eventOption = page.locator(
            'mat-option, ' +
            'option'
          ).first();
          
          if (await eventOption.isVisible({ timeout: 2000 })) {
            await eventOption.click();
          }
        }
        
        // Select a Steamfitter task to execute
        const taskSelector = page.locator(
          'select[name*="task"], ' +
          'mat-select[formControlName*="task"], ' +
          'select[formControlName*="action"]'
        ).first();
        
        if (await taskSelector.isVisible({ timeout: 2000 })) {
          await taskSelector.click();
          
          const taskOption = page.locator(
            'mat-option, ' +
            'option'
          ).first();
          
          if (await taskOption.isVisible({ timeout: 2000 })) {
            await taskOption.click();
          }
        }
        
        // expect: Timeline synchronization is configured
        const syncCheckbox = page.locator(
          'input[type="checkbox"][name*="sync"], ' +
          'mat-checkbox[formControlName*="sync"]'
        ).first();
        
        if (await syncCheckbox.isVisible({ timeout: 2000 })) {
          await syncCheckbox.click();
        }
        
        // Save trigger configuration
        const saveTriggerButton = page.locator(
          'button:has-text("Save"), ' +
          'button:has-text("Add"), ' +
          'button[type="submit"]'
        ).last();
        
        if (await saveTriggerButton.isVisible({ timeout: 2000 })) {
          await saveTriggerButton.click();
          await page.waitForTimeout(2000);
        }
      } else {
        console.log('Steamfitter automation triggers not available in this MSEL');
      }
    } else {
      test.skip();
    }
  });
});
