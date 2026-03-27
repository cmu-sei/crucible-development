// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect, chromium, BrowserContext } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Real-time Collaboration and SignalR', () => {
  test('Real-time MSEL Updates', async ({ page }) => {
    // 1. Open two browser windows, both viewing the same MSEL
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // expect: Both windows display the same MSEL details
    await page.waitForLoadState('networkidle');
    
    // Navigate to an existing MSEL or create one
    const mselLink = page.locator('a[href*="/msel"], div[class*="msel"]').first();
    let mselUrl = '';
    
    if (await mselLink.isVisible({ timeout: 5000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      mselUrl = page.url();
    } else {
      // Create a new MSEL for testing
      const createButton = page.locator('button:has-text("Create MSEL"), button:has-text("Add MSEL")').first();
      if (await createButton.isVisible({ timeout: 5000 })) {
        await createButton.click();
        await page.waitForTimeout(1000);
        
        const nameField = page.locator('input[name="name"], input[formControlName="name"]').first();
        await nameField.fill('Real-time Test MSEL');
        
        const saveButton = page.locator('button:has-text("Save"), button:has-text("Create")').last();
        await saveButton.click();
        await page.waitForTimeout(2000);
        await page.waitForLoadState('networkidle');
        mselUrl = page.url();
      }
    }
    
    // Open second browser context and window
    const browser = await chromium.launch();
    const context2 = await browser.newContext({ ignoreHTTPSErrors: true });
    const page2 = await context2.newPage();
    
    // Authenticate in second window
    await authenticateBlueprintWithKeycloak(page2, 'admin', 'admin');
    await page2.goto(mselUrl);
    await page2.waitForLoadState('networkidle');
    
    // expect: Both windows show the same MSEL
    const initialEventCount1 = await page.locator('[class*="event"], [class*="scenario"]').count();
    const initialEventCount2 = await page2.locator('[class*="event"], [class*="scenario"]').count();
    
    // 2. In window 1, create a new scenario event
    const addEventButton = page.locator(
      'button:has-text("Add Event"), ' +
      'button:has-text("Create Event"), ' +
      'button:has-text("New Event")'
    ).first();
    
    if (await addEventButton.isVisible({ timeout: 5000 })) {
      await addEventButton.click();
      
      // expect: Event is created in window 1
      await page.waitForTimeout(1000);
      
      // Fill in event details
      const descriptionField = page.locator(
        'input[name="description"], ' +
        'textarea[name="description"], ' +
        'input[formControlName="description"]'
      ).first();
      
      if (await descriptionField.isVisible({ timeout: 2000 })) {
        await descriptionField.fill('Real-time update test event');
        
        const saveEventButton = page.locator('button:has-text("Save"), button[type="submit"]').last();
        await saveEventButton.click();
        await page.waitForTimeout(2000);
      }
    }
    
    // 3. Observe window 2 without refreshing
    // expect: Window 2 receives real-time update via SignalR
    // expect: New event appears automatically in window 2
    // expect: No manual refresh is required
    
    // Wait for SignalR to propagate the update (typically 1-3 seconds)
    await page2.waitForTimeout(3000);
    
    const finalEventCount2 = await page2.locator('[class*="event"], [class*="scenario"]').count();
    
    // Verify that the event count increased in window 2 or that the new event text is visible
    const newEventInWindow2 = page2.locator('text=Real-time update test event');
    
    // Check either the count increased or the event is visible
    const eventAppeared = await newEventInWindow2.isVisible({ timeout: 5000 }).catch(() => false);
    const countIncreased = finalEventCount2 > initialEventCount2;
    
    expect(eventAppeared || countIncreased).toBeTruthy();
    
    // Cleanup
    await context2.close();
    await browser.close();
  });
});
