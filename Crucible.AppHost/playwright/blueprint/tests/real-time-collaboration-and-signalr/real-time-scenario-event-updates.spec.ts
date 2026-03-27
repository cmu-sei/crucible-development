// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect, chromium, BrowserContext } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Real-time Collaboration and SignalR', () => {
  test('Real-time Scenario Event Updates', async ({ page }) => {
    // 1. Open two windows viewing the same MSEL timeline
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    await page.waitForLoadState('networkidle');
    
    // Navigate to an existing MSEL with events
    const mselLink = page.locator('a[href*="/msel"], div[class*="msel"]').first();
    let mselUrl = '';
    
    if (await mselLink.isVisible({ timeout: 5000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      mselUrl = page.url();
    }
    
    // expect: Both windows show the same timeline
    // Open second browser context
    const browser = await chromium.launch();
    const context2 = await browser.newContext({ ignoreHTTPSErrors: true });
    const page2 = await context2.newPage();
    
    await authenticateBlueprintWithKeycloak(page2, 'admin', 'admin');
    await page2.goto(mselUrl);
    await page2.waitForLoadState('networkidle');
    
    // Find an existing event to edit
    const existingEvent = page.locator('[class*="event"], [class*="scenario"]').first();
    
    if (await existingEvent.isVisible({ timeout: 5000 })) {
      // Get initial event text in window 2
      const eventSelector = '[class*="event"], [class*="scenario"]';
      const initialEventText = await page2.locator(eventSelector).first().textContent();
      
      // 2. In window 1, edit an existing event
      const editButton = existingEvent.locator('button[class*="edit"], mat-icon:has-text("edit")').first();
      
      if (await editButton.isVisible({ timeout: 2000 })) {
        await editButton.click();
      } else {
        await existingEvent.click();
      }
      
      await page.waitForTimeout(1000);
      
      // expect: Event is updated in window 1
      const descriptionField = page.locator(
        'input[name="description"], ' +
        'textarea[name="description"], ' +
        'input[formControlName="description"]'
      ).first();
      
      if (await descriptionField.isVisible({ timeout: 2000 })) {
        await descriptionField.clear();
        await descriptionField.fill('Updated via real-time test at ' + new Date().toISOString());
        
        const saveButton = page.locator('button:has-text("Save"), button[type="submit"]').last();
        await saveButton.click();
        await page.waitForTimeout(2000);
      }
      
      // 3. Observe window 2
      // expect: Event updates automatically in window 2
      // expect: Changes are reflected in real-time
      // expect: Color or position changes are immediately visible
      
      // Wait for SignalR to propagate the update
      await page2.waitForTimeout(3000);
      
      const updatedEventText = await page2.locator(eventSelector).first().textContent();
      
      // Verify that the event was updated
      const updateText = page2.locator('text=Updated via real-time test');
      const textUpdated = await updateText.isVisible({ timeout: 5000 }).catch(() => false);
      const textChanged = initialEventText !== updatedEventText;
      
      expect(textUpdated || textChanged).toBeTruthy();
    }
    
    // Cleanup
    await context2.close();
    await browser.close();
  });
});
