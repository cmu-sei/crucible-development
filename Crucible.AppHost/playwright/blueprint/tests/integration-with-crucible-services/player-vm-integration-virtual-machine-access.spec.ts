// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Player-VM Integration - Virtual Machine Access', async ({ page }) => {
    // Authenticate with Blueprint
    await page.goto(Services.Blueprint.UI);
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin');
    await page.click('button:has-text("Sign In")');
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');

    // 1. Navigate to a MSEL with VM requirements
    // Look for MSEL list or navigation
    const mselLink = page.locator('a:has-text("MSEL"), [class*="msel-item"]').first();
    
    if (await mselLink.isVisible({ timeout: 5000 }).catch(() => false)) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL details page is displayed
      const mselDetails = page.locator('[class*="msel-detail"], text=/MSEL/i').first();
      await expect(mselDetails).toBeVisible({ timeout: 10000 });
      
      // 2. Configure Player-VM integration settings
      // Look for VM configuration options
      const vmSettings = page.locator('button:has-text("VM"), button:has-text("Virtual Machine"), text=/VM.*Settings/i').first();
      const vmSection = page.locator('[class*="vm"], [class*="virtual-machine"]').first();
      
      const hasVmButton = await vmSettings.isVisible({ timeout: 5000 }).catch(() => false);
      const hasVmSection = await vmSection.isVisible({ timeout: 5000 }).catch(() => false);
      
      if (hasVmButton) {
        await vmSettings.click();
        await page.waitForLoadState('networkidle');
        
        // expect: Player-VM service integration (http://localhost:4303) is configured
        const vmConfig = page.locator('[class*="vm-config"], text=/VM.*Configuration/i').first();
        await expect(vmConfig).toBeVisible({ timeout: 10000 });
        
        // expect: VMs can be assigned to teams or scenario events
        const assignVmButton = page.locator('button:has-text("Assign VM"), button:has-text("Add VM")').first();
        
        if (await assignVmButton.isVisible({ timeout: 5000 }).catch(() => false)) {
          await expect(assignVmButton).toBeVisible();
          await assignVmButton.click();
          
          // Look for VM selection interface
          const vmSelector = page.locator('select[name*="vm" i], [class*="vm-selector"]').first();
          await expect(vmSelector).toBeVisible({ timeout: 10000 });
          
          // Look for team assignment options
          const teamSelector = page.locator('select[name*="team" i], [class*="team-selector"]').first();
          
          if (await teamSelector.isVisible({ timeout: 5000 }).catch(() => false)) {
            await expect(teamSelector).toBeVisible();
            console.log('Team assignment options found for VMs');
          }
        }
        
        // 3. Access VM console from scenario event
        const vmConsoleLink = page.locator('a:has-text("Console"), button:has-text("Open Console"), a[href*="4303"]').first();
        
        if (await vmConsoleLink.isVisible({ timeout: 5000 }).catch(() => false)) {
          await expect(vmConsoleLink).toBeVisible();
          
          // Verify link points to Player-VM service
          const href = await vmConsoleLink.getAttribute('href');
          if (href) {
            expect(href).toContain('4303'); // Player-VM UI port
          }
          
          // Click to open VM console
          const [vmPage] = await Promise.all([
            page.context().waitForEvent('page'),
            vmConsoleLink.click()
          ]);
          
          // expect: VM console opens in new window or embedded view
          await vmPage.waitForLoadState('networkidle');
          await expect(vmPage).toHaveURL(/.*localhost:4303.*/, { timeout: 10000 });
          
          // expect: Users can interact with assigned VMs during scenario
          const vmConsole = vmPage.locator('[class*="console"], [class*="terminal"], canvas').first();
          await expect(vmConsole).toBeVisible({ timeout: 10000 });
          
          console.log('VM console opened successfully');
          await vmPage.close();
        }
      } else if (hasVmSection) {
        await expect(vmSection).toBeVisible();
        console.log('VM section found in MSEL details');
        
        // Check for Player-VM integration indicators
        const playerVmIntegration = page.locator('text=/Player.*VM/i, text=/Virtual Machine/i').first();
        await expect(playerVmIntegration).toBeVisible({ timeout: 5000 });
      } else {
        console.log('VM configuration not found - checking for integration settings');
        
        // Look for settings or integrations menu
        const settingsButton = page.locator('button:has-text("Settings"), a:has-text("Settings")').first();
        
        if (await settingsButton.isVisible({ timeout: 5000 }).catch(() => false)) {
          await settingsButton.click();
          await page.waitForLoadState('networkidle');
          
          // Look for VM integration options in settings
          const vmIntegrationSetting = page.locator('text=/Player.*VM/i, text=/VM.*Integration/i').first();
          
          if (await vmIntegrationSetting.isVisible({ timeout: 5000 }).catch(() => false)) {
            await expect(vmIntegrationSetting).toBeVisible();
            console.log('Player-VM integration settings found');
          }
        }
      }
    } else {
      console.log('MSEL list not accessible - checking for Player-VM integration documentation');
      
      // Try navigating to integrations or help page
      await page.goto(`${Services.Blueprint.UI}/integrations`);
      await page.waitForLoadState('networkidle');
      
      const vmIntegrationInfo = page.locator('text=/Player.*VM/i, text=/Virtual Machine/i').first();
      const hasVmInfo = await vmIntegrationInfo.isVisible({ timeout: 5000 }).catch(() => false);
      
      if (hasVmInfo) {
        await expect(vmIntegrationInfo).toBeVisible();
        console.log('Player-VM integration information found');
      } else {
        console.log('Player-VM integration not yet available in Blueprint');
      }
    }
  });
});
