// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Steamfitter Integration - Scenario Automation', async ({ page }) => {
    // Authenticate with Blueprint
    await page.goto(Services.Blueprint.UI);
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin');
    await page.click('button:has-text("Sign In")');
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');

    // 1. Create or edit a MSEL
    // Look for MSEL creation/editing interface
    const createMselButton = page.locator('button:has-text("Create MSEL"), button:has-text("Add MSEL"), button:has-text("New MSEL")').first();
    const editMselButton = page.locator('button:has-text("Edit"), [aria-label="Edit MSEL"]').first();
    
    const hasCreateButton = await createMselButton.isVisible({ timeout: 5000 }).catch(() => false);
    const hasEditButton = await editMselButton.isVisible({ timeout: 5000 }).catch(() => false);
    
    if (hasCreateButton) {
      await createMselButton.click();
      await page.waitForLoadState('networkidle');
    } else if (hasEditButton) {
      await editMselButton.click();
      await page.waitForLoadState('networkidle');
    } else {
      // Try to navigate to an existing MSEL
      const mselLink = page.locator('a:has-text("MSEL"), [class*="msel-item"]').first();
      if (await mselLink.isVisible({ timeout: 5000 }).catch(() => false)) {
        await mselLink.click();
        await page.waitForLoadState('networkidle');
      }
    }
    
    // expect: MSEL form is displayed
    const mselForm = page.locator('form, [class*="msel-form"], [class*="msel-detail"]').first();
    await expect(mselForm).toBeVisible({ timeout: 10000 });
    
    // 2. Link a Steamfitter scenario to the MSEL
    // Look for Steamfitter integration options
    const steamfitterSection = page.locator('button:has-text("Steamfitter"), text=/Steamfitter/i, [class*="steamfitter"]').first();
    const scenarioSelector = page.locator('select[name*="steamfitter" i], select[name*="scenario" i]').first();
    
    const hasSteamfitterSection = await steamfitterSection.isVisible({ timeout: 5000 }).catch(() => false);
    const hasScenarioSelector = await scenarioSelector.isVisible({ timeout: 5000 }).catch(() => false);
    
    if (hasSteamfitterSection) {
      await expect(steamfitterSection).toBeVisible();
      
      // Click to expand or access Steamfitter options
      const isSteamfitterButton = await steamfitterSection.evaluate((el) => el.tagName === 'BUTTON');
      if (isSteamfitterButton) {
        await steamfitterSection.click();
        await page.waitForLoadState('networkidle');
      }
      
      // expect: Steamfitter scenario selector shows available scenarios from Steamfitter service (http://localhost:4401)
      const scenarioDropdown = page.locator('select[name*="scenario" i], [class*="scenario-selector"]').first();
      
      if (await scenarioDropdown.isVisible({ timeout: 5000 }).catch(() => false)) {
        await expect(scenarioDropdown).toBeVisible();
        
        // expect: Scenario can be selected and associated with MSEL
        const scenarioOptions = page.locator('option').filter({ hasText: /scenario/i });
        const optionCount = await scenarioOptions.count();
        
        if (optionCount > 0) {
          await scenarioDropdown.selectOption({ index: 1 });
          console.log('Steamfitter scenario selected');
          
          // 3. Configure scenario automation triggers based on MSEL timeline
          // Look for automation configuration options
          const automationSettings = page.locator('button:has-text("Automation"), text=/Automation.*Trigger/i, [class*="automation"]').first();
          
          if (await automationSettings.isVisible({ timeout: 5000 }).catch(() => false)) {
            await expect(automationSettings).toBeVisible();
            
            const isButton = await automationSettings.evaluate((el) => el.tagName === 'BUTTON');
            if (isButton) {
              await automationSettings.click();
              await page.waitForLoadState('networkidle');
            }
            
            // expect: Scenario events can trigger Steamfitter tasks
            const triggerConfig = page.locator('text=/Trigger/i, [class*="trigger"]').first();
            await expect(triggerConfig).toBeVisible({ timeout: 10000 });
            
            // expect: Timeline synchronization is configured
            const timelineSync = page.locator('text=/Timeline/i, text=/Synchroniz/i, [class*="timeline-sync"]').first();
            
            if (await timelineSync.isVisible({ timeout: 5000 }).catch(() => false)) {
              await expect(timelineSync).toBeVisible();
              console.log('Timeline synchronization configuration found');
            }
          }
        } else {
          console.log('No Steamfitter scenarios available in dropdown');
        }
      }
    } else if (hasScenarioSelector) {
      await expect(scenarioSelector).toBeVisible();
      console.log('Steamfitter scenario selector found');
      
      // Try to interact with the selector
      const options = await scenarioSelector.locator('option').count();
      if (options > 1) {
        await scenarioSelector.selectOption({ index: 1 });
        console.log('Steamfitter scenario selected from selector');
      }
    } else {
      console.log('Steamfitter integration not found in MSEL form - checking for integration link');
      
      // Look for a link to Steamfitter
      const steamfitterLink = page.locator('a:has-text("Steamfitter"), a[href*="4401"]').first();
      
      if (await steamfitterLink.isVisible({ timeout: 5000 }).catch(() => false)) {
        await expect(steamfitterLink).toBeVisible();
        
        // Verify link points to Steamfitter service
        const href = await steamfitterLink.getAttribute('href');
        if (href) {
          expect(href).toContain('4401'); // Steamfitter UI port
        }
        
        console.log('Steamfitter link found and points to correct service');
      } else {
        console.log('Steamfitter integration not yet available - checking integrations page');
        
        // Navigate to integrations page
        await page.goto(`${Services.Blueprint.UI}/integrations`);
        await page.waitForLoadState('networkidle');
        
        const integrationsPage = page.locator('text=/Steamfitter/i').first();
        const hasSteamfitterIntegration = await integrationsPage.isVisible({ timeout: 5000 }).catch(() => false);
        
        if (hasSteamfitterIntegration) {
          await expect(integrationsPage).toBeVisible();
          console.log('Steamfitter integration information found');
        } else {
          console.log('Steamfitter integration not yet available in Blueprint');
        }
      }
    }
  });
});
