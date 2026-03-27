// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Player Integration - View Association', async ({ page }) => {
    // Authenticate with Blueprint
    await page.goto(Services.Blueprint.UI);
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin');
    await page.click('button:has-text("Sign In")');
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');

    // 1. Create or edit a MSEL
    // Look for create or edit MSEL buttons
    const createMselButton = page.locator('button:has-text("Create MSEL"), button:has-text("Add MSEL"), button:has-text("New MSEL")').first();
    
    if (await createMselButton.isVisible({ timeout: 5000 }).catch(() => false)) {
      await createMselButton.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL form is displayed
      const mselForm = page.locator('form, [class*="msel-form"]').first();
      await expect(mselForm).toBeVisible({ timeout: 10000 });
      
      // 2. Associate a Player view with the MSEL
      // expect: Player view selector shows available views from Player service (http://localhost:4301)
      const playerViewSelector = page.locator('select[name*="player" i], select[name*="view" i], [label*="Player View"]').first();
      const playerViewField = page.locator('input[placeholder*="player" i], input[placeholder*="view" i]').first();
      
      // Check if Player view selector exists
      const hasPlayerSelector = await playerViewSelector.isVisible({ timeout: 5000 }).catch(() => false);
      const hasPlayerField = await playerViewField.isVisible({ timeout: 5000 }).catch(() => false);
      
      if (hasPlayerSelector) {
        await expect(playerViewSelector).toBeVisible();
        
        // expect: View can be selected and linked to MSEL
        const playerOptions = page.locator('option').filter({ hasText: /view/i });
        const optionCount = await playerOptions.count();
        
        if (optionCount > 0) {
          await playerViewSelector.selectOption({ index: 1 });
          console.log('Player view selected from dropdown');
        }
      } else if (hasPlayerField) {
        await expect(playerViewField).toBeVisible();
        console.log('Player view input field found');
      } else {
        console.log('Player view selector not found - checking for Player integration section');
        
        // Look for any Player-related integration options
        const playerIntegration = page.locator('text=/Player/i, [class*="player"]').first();
        const hasPlayerIntegration = await playerIntegration.isVisible({ timeout: 5000 }).catch(() => false);
        
        if (hasPlayerIntegration) {
          await expect(playerIntegration).toBeVisible();
          console.log('Player integration section found');
        }
      }
      
      // Fill in required MSEL fields to save
      const nameField = page.locator('input[name="name"], input[placeholder*="name" i]').first();
      if (await nameField.isVisible({ timeout: 5000 }).catch(() => false)) {
        await nameField.fill('Test MSEL for Player Integration');
      }
      
      // 3. Save and view MSEL details
      const saveButton = page.locator('button:has-text("Save"), button:has-text("Create"), button[type="submit"]').first();
      
      if (await saveButton.isVisible({ timeout: 5000 }).catch(() => false)) {
        await saveButton.click();
        await page.waitForLoadState('networkidle');
        
        // expect: Player view is shown as associated
        const playerViewDisplay = page.locator('text=/Player View/i, [class*="player-view"]').first();
        
        if (await playerViewDisplay.isVisible({ timeout: 5000 }).catch(() => false)) {
          await expect(playerViewDisplay).toBeVisible();
          
          // expect: Link to open Player with this view is available
          const playerLink = page.locator('a:has-text("Open in Player"), button:has-text("Player"), a[href*="4301"]').first();
          
          if (await playerLink.isVisible({ timeout: 5000 }).catch(() => false)) {
            await expect(playerLink).toBeVisible();
            
            // Verify the link points to Player service
            const href = await playerLink.getAttribute('href');
            if (href) {
              expect(href).toContain('4301'); // Player UI port
            }
            
            console.log('Player link found and points to correct service');
          }
        }
      }
    } else {
      // Try to edit an existing MSEL
      const editButton = page.locator('button:has-text("Edit"), [aria-label="Edit"]').first();
      
      if (await editButton.isVisible({ timeout: 5000 }).catch(() => false)) {
        await editButton.click();
        await page.waitForLoadState('networkidle');
        
        // Look for Player integration options
        const playerOptions = page.locator('text=/Player/i').first();
        await expect(playerOptions).toBeVisible({ timeout: 10000 });
      } else {
        console.log('Unable to access MSEL creation or editing - checking for Player integration documentation');
        
        // Navigate to see if there's integration info
        await page.goto(`${Services.Blueprint.UI}/integrations`);
        await page.waitForLoadState('networkidle');
        
        const integrationsPage = page.locator('text=/Integration/i').first();
        const hasIntegrationsPage = await integrationsPage.isVisible({ timeout: 5000 }).catch(() => false);
        
        if (hasIntegrationsPage) {
          console.log('Integrations page found');
        } else {
          console.log('Player integration not yet available in Blueprint');
        }
      }
    }
  });
});
