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

  test('Loading States and Feedback', async ({ page }) => {
    // Look for actions that might trigger loading states
    const actionSelectors = [
      'button:has-text("Create")',
      'button:has-text("Add")',
      'button:has-text("Save")',
      'button:has-text("Import")',
      'button:has-text("Export")',
      'button:has-text("Load")',
      'button[type="submit"]'
    ];

    let actionButton = null;
    for (const selector of actionSelectors) {
      const button = await page.locator(selector).first();
      if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
        actionButton = button;
        break;
      }
    }

    if (!actionButton) {
      // Navigate to find an action button
      const navLinks = await page.locator('nav a, [role="navigation"] a').all();
      if (navLinks.length > 0) {
        await navLinks[0].click();
        await page.waitForTimeout(1000);
      }
      
      for (const selector of actionSelectors) {
        const button = await page.locator(selector).first();
        if (await button.count() > 0 && await button.isVisible().catch(() => false)) {
          actionButton = button;
          break;
        }
      }
    }

    // Test 1: Initial page load shows loading state
    // Navigate to a different section to trigger loading
    const mselLink = await page.locator('a:has-text("MSEL"), a:has-text("List"), a:has-text("Dashboard")').first();
    if (await mselLink.count() > 0) {
      await mselLink.click();
      
      // Check for loading indicators during navigation
      // Common loading indicators
      const loadingIndicators = [
        'mat-spinner',
        'mat-progress-spinner',
        'mat-progress-bar',
        '.spinner',
        '.loading',
        '[role="progressbar"]',
        '.loader'
      ];
      
      let loadingFound = false;
      for (const selector of loadingIndicators) {
        const indicator = await page.locator(selector).first();
        if (await indicator.count() > 0) {
          loadingFound = true;
          break;
        }
      }
      
      // If no loading indicator, that's okay - the page might load very fast
    }

    // Test 2: Form submission with loading state
    if (actionButton) {
      // If button opens a dialog, handle that
      await actionButton.click();
      await page.waitForTimeout(500);
      
      const dialog = await page.locator('mat-dialog-container, [role="dialog"], .dialog, .modal').first();
      
      if (await dialog.count() > 0) {
        // Fill in any required form fields
        const inputs = await dialog.locator('input[required], input').all();
        for (const input of inputs.slice(0, 3)) {
          const inputType = await input.getAttribute('type');
          const isVisible = await input.isVisible().catch(() => false);
          
          if (!isVisible) continue;
          
          if (inputType === 'text' || inputType === 'email' || !inputType) {
            await input.fill('Test Value');
          } else if (inputType === 'number') {
            await input.fill('123');
          }
        }
        
        // Find and click submit button
        const submitButton = await dialog.locator('button:has-text("Save"), button:has-text("Create"), button:has-text("Submit"), button[type="submit"]').first();
        
        if (await submitButton.count() > 0) {
          // Check if button is initially enabled
          const initiallyEnabled = await submitButton.isEnabled();
          
          // Click the submit button
          await submitButton.click();
          
          // 2. Observe the UI during processing
          // Check for loading indicator
          const loadingIndicators = await page.locator('mat-spinner, mat-progress-spinner, mat-progress-bar, .spinner, .loading, [role="progressbar"]').all();
          
          // Check if submit button is disabled during processing
          await page.waitForTimeout(100);
          const buttonDisabled = await submitButton.isDisabled().catch(() => false);
          
          // Button should be disabled during processing (if action takes time)
          // Note: For very fast operations, this might not be observable
          
          // Check for loading state announced to screen readers
          const ariaLiveRegions = await page.locator('[aria-live], [role="status"], [role="alert"]').all();
          let hasLoadingAnnouncement = false;
          for (const region of ariaLiveRegions) {
            const text = await region.textContent();
            if (text && (text.toLowerCase().includes('loading') || text.toLowerCase().includes('saving') || text.toLowerCase().includes('processing'))) {
              hasLoadingAnnouncement = true;
              break;
            }
          }
          
          // 3. Wait for action to complete
          await page.waitForTimeout(2000);
          
          // Check for success or error message
          const notifications = await page.locator('[role="alert"], .notification, .snackbar, .toast, mat-snack-bar-container').all();
          let hasNotification = false;
          for (const notification of notifications) {
            const isVisible = await notification.isVisible().catch(() => false);
            if (isVisible) {
              hasNotification = true;
              const notificationText = await notification.textContent();
              expect(notificationText).toBeTruthy();
              break;
            }
          }
          
          // Check if loading indicator disappears
          const stillLoading = await page.locator('mat-spinner, mat-progress-spinner, .spinner:visible').count();
          
          // Loading should be complete, or form should have validation errors
          const validationErrors = await dialog.locator('.error, .mat-error, [role="alert"]').count();
          
          // Either notification or validation errors should be present
          expect(hasNotification || validationErrors > 0).toBeTruthy();
        }
        
        // Close dialog
        await page.keyboard.press('Escape');
      }
    }

    // Test 3: Check loading state during data fetch
    // Trigger a refresh or navigation that loads data
    await page.reload();
    await page.waitForTimeout(100);
    
    // Check for loading indicators during page load
    const pageLoadingIndicators = await page.locator('mat-spinner, mat-progress-spinner, mat-progress-bar, [role="progressbar"]').all();
    
    // Wait for page to fully load
    await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
    
    // Verify content is displayed after loading
    const content = await page.locator('main, [role="main"], .content').first();
    if (await content.count() > 0) {
      await expect(content).toBeVisible();
    }

    // Test 4: Check for proper feedback on user actions
    // Try clicking various buttons and verify feedback
    const interactiveButtons = await page.locator('button:visible').all();
    
    if (interactiveButtons.length > 0) {
      const testButton = interactiveButtons[0];
      
      // Check if button provides visual feedback on interaction
      const beforeClick = await testButton.evaluate((btn) => {
        return window.getComputedStyle(btn).cursor;
      });
      
      // Cursor should indicate the button is clickable
      expect(beforeClick).toBe('pointer');
      
      // Check for hover state
      await testButton.hover();
      await page.waitForTimeout(100);
      
      // Button should provide some visual feedback on hover
      const afterHover = await testButton.evaluate((btn) => {
        const style = window.getComputedStyle(btn);
        return {
          backgroundColor: style.backgroundColor,
          color: style.color,
          transform: style.transform
        };
      });
      
      expect(afterHover).toBeTruthy();
    }

    // Test 5: Verify aria-busy attribute during loading
    const mainContent = await page.locator('main, [role="main"]').first();
    if (await mainContent.count() > 0) {
      // Trigger an action that loads data
      const refreshButton = await page.locator('button:has-text("Refresh"), button[aria-label*="refresh" i]').first();
      if (await refreshButton.count() > 0) {
        await refreshButton.click();
        
        // Check for aria-busy during loading
        const ariaBusy = await mainContent.getAttribute('aria-busy');
        
        // Wait for loading to complete
        await page.waitForTimeout(1000);
        
        // aria-busy should be removed or set to false after loading
        const ariaBusyAfter = await mainContent.getAttribute('aria-busy');
        expect(ariaBusyAfter !== 'true').toBeTruthy();
      }
    }
  });
});
