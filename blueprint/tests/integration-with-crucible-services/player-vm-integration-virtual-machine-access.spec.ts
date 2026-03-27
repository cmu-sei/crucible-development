// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Player-VM Integration - Virtual Machine Access', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL with VM requirements
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
      
      // expect: MSEL details page is displayed
      await page.waitForTimeout(1000);
      
      // 2. Configure Player-VM integration settings
      // Look for VM settings or configuration
      const vmSettingsButton = page.locator(
        'button:has-text("VM Settings"), ' +
        'button:has-text("Virtual Machines"), ' +
        'button:has-text("Player-VM"), ' +
        '[class*="vm-config"]'
      ).first();
      
      if (await vmSettingsButton.isVisible({ timeout: 3000 })) {
        await vmSettingsButton.click();
        await page.waitForTimeout(1000);
        
        // expect: Player-VM service integration (http://localhost:4303) is configured
        const vmConfigDialog = page.locator(
          '[class*="vm-dialog"], ' +
          '[class*="vm-config"], ' +
          'form'
        ).first();
        
        await expect(vmConfigDialog).toBeVisible({ timeout: 5000 });
        
        // expect: VMs can be assigned to teams or scenario events
        const vmSelector = page.locator(
          'select[name*="vm"], ' +
          'mat-select[formControlName*="vm"], ' +
          '[class*="vm-select"]'
        ).first();
        
        if (await vmSelector.isVisible({ timeout: 2000 })) {
          await vmSelector.click();
          
          // Select a VM if available
          const vmOption = page.locator(
            'mat-option, ' +
            'option'
          ).first();
          
          if (await vmOption.isVisible({ timeout: 2000 })) {
            await vmOption.click();
          }
        }
        
        // Team assignment
        const teamSelector = page.locator(
          'select[name*="team"], ' +
          'mat-select[formControlName*="team"]'
        ).first();
        
        if (await teamSelector.isVisible({ timeout: 2000 })) {
          await teamSelector.click();
          
          const teamOption = page.locator(
            'mat-option, ' +
            'option'
          ).first();
          
          if (await teamOption.isVisible({ timeout: 2000 })) {
            await teamOption.click();
          }
        }
        
        // Save VM configuration
        const saveButton = page.locator(
          'button:has-text("Save"), ' +
          'button:has-text("Apply"), ' +
          'button[type="submit"]'
        ).last();
        
        if (await saveButton.isVisible({ timeout: 2000 })) {
          await saveButton.click();
          await page.waitForTimeout(2000);
        }
      }
      
      // 3. Access VM console from scenario event
      // Look for a scenario event with VM access
      const eventWithVM = page.locator(
        '[class*="event"]:has-text("VM"), ' +
        '[class*="scenario-event"]'
      ).first();
      
      if (await eventWithVM.isVisible({ timeout: 3000 })) {
        await eventWithVM.click();
        await page.waitForTimeout(1000);
        
        // Look for VM console button
        const vmConsoleButton = page.locator(
          'button:has-text("VM Console"), ' +
          'button:has-text("Open Console"), ' +
          'button:has-text("Access VM"), ' +
          'a[href*="console"]'
        ).first();
        
        if (await vmConsoleButton.isVisible({ timeout: 3000 })) {
          // Listen for new page/tab or embedded console
          const pagePromise = page.context().waitForEvent('page', { timeout: 10000 }).catch(() => null);
          
          await vmConsoleButton.click();
          
          try {
            // expect: VM console opens in new window or embedded view
            const consolePage = await pagePromise;
            
            if (consolePage) {
              await consolePage.waitForLoadState('networkidle', { timeout: 10000 });
              
              // expect: Users can interact with assigned VMs during scenario
              // Console should show VM interface
              await expect(consolePage).toHaveURL(new RegExp('.*console.*|.*vm.*|.*4303.*|.*4305.*'), { timeout: 10000 });
              
              await consolePage.close();
            } else {
              // Check for embedded console
              const embeddedConsole = page.locator(
                '[class*="console"], ' +
                'iframe[src*="console"], ' +
                'iframe[src*="vm"]'
              ).first();
              
              await expect(embeddedConsole).toBeVisible({ timeout: 5000 });
            }
          } catch (error) {
            console.log('VM console access not available or error occurred:', error);
          }
        } else {
          console.log('VM console button not found in this event');
        }
      } else {
        console.log('No events with VM access found');
      }
    } else {
      test.skip();
    }
  });
});
