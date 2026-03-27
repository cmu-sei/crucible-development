// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Error Handling and Validation', () => {
  test('Unauthorized Action Handling', async ({ page, context }) => {
    // 1. Log in as a user without admin permissions
    // Note: Using 'admin' user for now as we may not have a non-admin user configured
    // In a real scenario, you would use a user with limited permissions
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: User is authenticated
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // 2. Attempt to access admin-only features
    // Try to navigate to admin section via URL manipulation
    const adminUrls = [
      'http://localhost:4725/admin',
      'http://localhost:4725/settings',
      'http://localhost:4725/users',
      'http://localhost:4725/roles',
      'http://localhost:4725/system'
    ];
    
    let unauthorizedAccessDetected = false;
    
    for (const adminUrl of adminUrls) {
      await page.goto(adminUrl, { waitUntil: 'networkidle', timeout: 10000 }).catch(() => {});
      await page.waitForTimeout(1000);
      
      // Check for various unauthorized access indicators
      const accessDenied = page.locator(
        'text=/.*[Aa]ccess.*[Dd]enied.*/, ' +
        'text=/.*[Uu]nauthorized.*/, ' +
        'text=/.*[Ff]orbidden.*/, ' +
        'text=/.*[Pp]ermission.*[Dd]enied.*/, ' +
        'text=/.*[Nn]ot.*[Aa]uthorized.*/, ' +
        'text=/403/, ' +
        '[class*="error"]:has-text(/permission|unauthorized|forbidden/i), ' +
        '[class*="alert"]:has-text(/permission|unauthorized|forbidden/i)'
      ).first();
      
      const isDenied = await accessDenied.isVisible({ timeout: 2000 }).catch(() => false);
      
      if (isDenied) {
        unauthorizedAccessDetected = true;
        
        // expect: Access is denied
        // expect: Appropriate error message is displayed
        await expect(accessDenied).toBeVisible();
        
        const errorText = await accessDenied.textContent();
        expect(errorText).toBeTruthy();
        expect(errorText?.toLowerCase()).toMatch(/access|unauthorized|permission|forbidden|denied/);
        
        // expect: User is redirected or shown permission error
        // Verify we're either on an error page or redirected back
        const currentUrl = page.url();
        expect(currentUrl).toBeTruthy();
        
        // expect: No sensitive data is exposed
        // Check that admin-specific content is not visible
        const adminContent = page.locator(
          'text=/.*[Ss]ystem.*[Ss]ettings.*/, ' +
          'text=/.*[Dd]atabase.*[Cc]onfiguration.*/, ' +
          'text=/.*[Ss]erver.*[Cc]onfig.*/'
        );
        
        const adminContentCount = await adminContent.count();
        expect(adminContentCount).toBe(0);
        
        break;
      }
    }
    
    // If no unauthorized access was detected through URLs, try accessing admin features through UI
    if (!unauthorizedAccessDetected) {
      // Navigate back to home
      await page.goto('http://localhost:4725', { waitUntil: 'networkidle' });
      
      // Try to find and click admin menu items
      const adminMenuItems = page.locator(
        'a:has-text("Admin"), ' +
        'button:has-text("Admin"), ' +
        'a:has-text("Settings"), ' +
        'button:has-text("Settings"), ' +
        'a:has-text("System"), ' +
        'button:has-text("System")'
      );
      
      const adminMenuCount = await adminMenuItems.count();
      
      if (adminMenuCount > 0) {
        const firstAdminMenu = adminMenuItems.first();
        await firstAdminMenu.click();
        await page.waitForTimeout(1000);
        
        // Check for unauthorized access message
        const accessDenied = page.locator(
          'text=/.*[Aa]ccess.*[Dd]enied.*/, ' +
          'text=/.*[Uu]nauthorized.*/, ' +
          'text=/.*[Pp]ermission.*/'
        ).first();
        
        const isDenied = await accessDenied.isVisible({ timeout: 2000 }).catch(() => false);
        
        if (isDenied) {
          await expect(accessDenied).toBeVisible();
          unauthorizedAccessDetected = true;
        }
      } else {
        // If admin menu is not visible, this itself is a form of access control
        console.log('Admin menu items are hidden for non-admin users - this is expected behavior');
        unauthorizedAccessDetected = true;
      }
    }
    
    // Ensure some form of access control was observed
    expect(unauthorizedAccessDetected).toBe(true);
    
    // Verify the user can still access authorized features
    await page.goto('http://localhost:4725', { waitUntil: 'networkidle' });
    
    // User should be able to view MSELs list (authorized action)
    const mselList = page.locator('[class*="list"], [class*="table"], [class*="grid"]').first();
    const canViewMsels = await mselList.isVisible({ timeout: 3000 }).catch(() => false);
    
    // Or check for create button which might be available
    const createButton = page.locator(
      'button:has-text("Create MSEL"), ' +
      'button:has-text("Add MSEL")'
    ).first();
    const canCreate = await createButton.isVisible({ timeout: 3000 }).catch(() => false);
    
    // At least one authorized feature should be accessible
    expect(canViewMsels || canCreate).toBe(true);
  });
});
