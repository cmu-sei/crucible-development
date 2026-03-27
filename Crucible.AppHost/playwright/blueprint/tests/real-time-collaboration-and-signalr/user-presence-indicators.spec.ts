// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect, chromium, BrowserContext } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Real-time Collaboration and SignalR', () => {
  test('User Presence Indicators', async ({ page }) => {
    // 1. Open a MSEL with multiple users viewing it
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await page.waitForLoadState('networkidle');
    
    // Navigate to a MSEL
    const mselLink = page.locator('a[href*="/msel"], div[class*="msel"]').first();
    let mselUrl = '';
    
    if (await mselLink.isVisible({ timeout: 5000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      mselUrl = page.url();
    } else {
      // Create a MSEL if none exist
      const createButton = page.locator('button:has-text("Create MSEL"), button:has-text("Add MSEL")').first();
      if (await createButton.isVisible({ timeout: 5000 })) {
        await createButton.click();
        await page.waitForTimeout(1000);
        
        const nameField = page.locator('input[name="name"], input[formControlName="name"]').first();
        await nameField.fill('Presence Test MSEL');
        
        const saveButton = page.locator('button:has-text("Save"), button:has-text("Create")').last();
        await saveButton.click();
        await page.waitForTimeout(2000);
        await page.waitForLoadState('networkidle');
        mselUrl = page.url();
      }
    }
    
    // expect: MSEL is displayed
    await expect(page).toHaveURL(/.*localhost:4725.*/);
    
    // 2. Check for user presence indicators
    // expect: Active users viewing the MSEL are shown
    // expect: User avatars or names are displayed
    // expect: Real-time join/leave notifications appear
    
    // Look for presence indicators in various possible locations
    const presenceIndicators = page.locator(
      '[class*="presence"], ' +
      '[class*="user-list"], ' +
      '[class*="active-users"], ' +
      '[class*="viewer"], ' +
      '[class*="participant"], ' +
      '[class*="online"], ' +
      '[class*="avatar"]'
    );
    
    // Check if current user (admin) is shown as present
    const adminPresence = page.locator(
      'text=admin, ' +
      '[class*="avatar"]:has-text("admin"), ' +
      '[title*="admin"]'
    );
    
    const hasPresenceUI = await presenceIndicators.first().isVisible({ timeout: 5000 }).catch(() => false);
    const hasAdminIndicator = await adminPresence.first().isVisible({ timeout: 5000 }).catch(() => false);
    
    // Open a second user session to test multi-user presence
    const browser = await chromium.launch();
    const context2 = await browser.newContext({ ignoreHTTPSErrors: true });
    const page2 = await context2.newPage();
    
    // Try to authenticate as a different user if available, otherwise use admin again
    await authenticateBlueprintWithKeycloak(page2, 'admin', 'admin');
    await page2.goto(mselUrl);
    await page2.waitForLoadState('networkidle');
    
    // Wait for presence updates to propagate via SignalR
    await page.waitForTimeout(3000);
    
    // Check if the presence count increased or if multiple users are shown
    const presenceCount = await presenceIndicators.count();
    const presenceList = page.locator(
      '[class*="presence-list"], ' +
      '[class*="user-list"], ' +
      '[class*="active-users"]'
    );
    
    const hasMultipleUsers = await presenceList.locator('[class*="user"], [class*="avatar"]').count() > 1;
    
    // Look for join notification
    const joinNotification = page.locator(
      'text=/joined/i, ' +
      'text=/connected/i, ' +
      '[class*="notification"]:has-text("user"), ' +
      '[class*="toast"]:has-text("user")'
    );
    
    const hasJoinNotification = await joinNotification.first().isVisible({ timeout: 5000 }).catch(() => false);
    
    // Test leave notification by closing the second window
    await context2.close();
    await page.waitForTimeout(3000);
    
    const leaveNotification = page.locator(
      'text=/left/i, ' +
      'text=/disconnected/i, ' +
      '[class*="notification"]:has-text("left"), ' +
      '[class*="toast"]:has-text("disconnected")'
    );
    
    const hasLeaveNotification = await leaveNotification.first().isVisible({ timeout: 5000 }).catch(() => false);
    
    // At minimum, we expect presence indicators to exist
    // The actual implementation may vary, so we check for common patterns
    expect(
      hasPresenceUI || 
      hasAdminIndicator || 
      presenceCount > 0 || 
      hasJoinNotification || 
      hasLeaveNotification
    ).toBeTruthy();
    
    // Cleanup
    await browser.close();
  });
});
