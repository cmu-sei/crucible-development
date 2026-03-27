// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Accessibility and Usability', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to Blueprint application
    await page.goto('http://localhost:4725');
    
    // Wait for Keycloak redirect
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    
    // Fill in username
    await page.fill('input[name="username"]', 'admin');
    
    // Fill in password
    await page.fill('input[name="password"]', 'admin');
    
    // Click Sign In button
    await page.click('button:has-text("Sign In")');
    
    // Wait for redirect back to Blueprint
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    
    // Verify main application loaded
    await expect(page).toHaveURL(/.*localhost:4725.*/);
  });

  test('Focus Management in Dialogs', async ({ page }) => {
    // Find a button that opens a dialog
    const dialogTriggers = [
      'button:has-text("Create")',
      'button:has-text("Add")',
      'button:has-text("New")',
      'button:has-text("Edit")',
      'button[aria-label*="create" i]',
      'button[aria-label*="add" i]'
    ];
    
    let triggerButton = null;
    for (const selector of dialogTriggers) {
      const button = await page.locator(selector).first();
      if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
        triggerButton = button;
        break;
      }
    }
    
    if (!triggerButton) {
      // Try to navigate to a section that might have dialogs
      const navLinks = await page.locator('nav a, [role="navigation"] a').all();
      if (navLinks.length > 0) {
        await navLinks[0].click();
        await page.waitForTimeout(1000);
      }
      
      // Try again to find a trigger button
      for (const selector of dialogTriggers) {
        const button = await page.locator(selector).first();
        if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
          triggerButton = button;
          break;
        }
      }
    }
    
    if (!triggerButton) {
      test.skip();
      return;
    }

    // Get the triggering element for later verification
    const triggerElementId = await triggerButton.evaluate((el) => {
      if (!el.id) {
        el.id = 'dialog-trigger-' + Date.now();
      }
      return el.id;
    });

    // 1. Open a dialog
    await triggerButton.click();
    await page.waitForTimeout(500); // Wait for dialog animation

    // Find the dialog
    const dialog = await page.locator('mat-dialog-container, [role="dialog"], .dialog, .modal, .cdk-overlay-pane').first();
    await expect(dialog).toBeVisible();

    // 2. Check focus behavior - Focus is moved to the dialog when it opens
    const focusedElement = await page.locator(':focus');
    
    // The focused element should be within the dialog
    const isFocusInDialog = await focusedElement.evaluate((el, dialogSelector) => {
      const dialogEl = document.querySelector(dialogSelector);
      return dialogEl ? dialogEl.contains(el) : false;
    }, 'mat-dialog-container, [role="dialog"], .dialog, .modal');
    
    expect(isFocusInDialog).toBeTruthy();

    // 3. Focus is trapped within the dialog
    // Get all focusable elements in the dialog
    const focusableElements = await dialog.locator('button, a, input, select, textarea, [tabindex]:not([tabindex="-1"])').all();
    expect(focusableElements.length).toBeGreaterThan(0);

    // Tab through dialog elements
    for (let i = 0; i < Math.min(focusableElements.length + 1, 10); i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(100);
      
      // Check that focus is still within the dialog
      const currentFocus = await page.locator(':focus');
      const stillInDialog = await currentFocus.evaluate((el, dialogSelector) => {
        const dialogEl = document.querySelector(dialogSelector);
        return dialogEl ? dialogEl.contains(el) : false;
      }, 'mat-dialog-container, [role="dialog"], .dialog, .modal');
      
      expect(stillInDialog).toBeTruthy();
    }

    // Test backward tabbing (Shift+Tab)
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press('Shift+Tab');
      await page.waitForTimeout(100);
      
      const currentFocus = await page.locator(':focus');
      const stillInDialog = await currentFocus.evaluate((el, dialogSelector) => {
        const dialogEl = document.querySelector(dialogSelector);
        return dialogEl ? dialogEl.contains(el) : false;
      }, 'mat-dialog-container, [role="dialog"], .dialog, .modal');
      
      expect(stillInDialog).toBeTruthy();
    }

    // 4. Escape key closes the dialog
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500); // Wait for close animation
    
    // Verify dialog is closed
    const dialogStillVisible = await dialog.isVisible().catch(() => false);
    expect(dialogStillVisible).toBe(false);

    // 5. When dialog closes, focus returns to the triggering element
    const currentFocusedId = await page.evaluate(() => {
      const el = document.activeElement;
      return el ? el.id : '';
    });
    
    expect(currentFocusedId).toBe(triggerElementId);

    // Test with another dialog if available
    // Open dialog again
    const triggerButtonAgain = await page.locator(`#${triggerElementId}`);
    await triggerButtonAgain.click();
    await page.waitForTimeout(500);

    // Verify dialog reopened
    await expect(dialog).toBeVisible();

    // Close using close button instead of Escape key
    const closeButton = await dialog.locator('button[mat-dialog-close], button:has-text("Cancel"), button:has-text("Close"), button[aria-label*="close" i]').first();
    if (await closeButton.count() > 0) {
      await closeButton.click();
      await page.waitForTimeout(500);
      
      // Verify dialog is closed
      const dialogClosed = await dialog.isVisible().catch(() => false);
      expect(dialogClosed).toBe(false);
      
      // Verify focus returned to trigger
      const finalFocusedId = await page.evaluate(() => {
        const el = document.activeElement;
        return el ? el.id : '';
      });
      
      expect(finalFocusedId).toBe(triggerElementId);
    }
  });
});
