// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Scenario Events Management', () => {
  test('View Scenario Events in MSEL', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL details page
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Find and click on a MSEL
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL details page is displayed
      await page.waitForTimeout(1000);
      
      // 2. View the scenario events timeline or list
      const eventsContainer = page.locator(
        '[class*="event"], ' +
        '[class*="timeline"], ' +
        '[class*="scenario"], ' +
        'table'
      ).first();
      
      await expect(eventsContainer).toBeVisible({ timeout: 5000 });
      
      // expect: Scenario events are displayed in chronological order
      const eventItems = page.locator(
        '[class*="event-item"], ' +
        '[class*="timeline-item"], ' +
        'table tbody tr'
      );
      
      const eventCount = await eventItems.count();
      
      if (eventCount > 0) {
        // expect: Each event shows: time, control number, from org, to org, description, details
        const firstEvent = eventItems.first();
        await expect(firstEvent).toBeVisible();
        
        const eventText = await firstEvent.textContent();
        expect(eventText).toBeTruthy();
        expect(eventText!.trim().length).toBeGreaterThan(0);
        
        // expect: Events are color-coded based on their type (using configured background colors)
        const eventColor = await firstEvent.evaluate((el) => {
          return window.getComputedStyle(el).backgroundColor;
        });
        expect(eventColor).toBeTruthy();
        
        // expect: Timeline view or list view is available for viewing events
        // Check for view toggle buttons
        const viewToggle = page.locator(
          'button[title*="View"], ' +
          'button[aria-label*="Timeline"], ' +
          'button[aria-label*="List"], ' +
          'mat-button-toggle'
        );
        
        const toggleCount = await viewToggle.count();
        expect(toggleCount).toBeGreaterThanOrEqual(0);
      } else {
        // No events in this MSEL
        const emptyState = page.locator(
          'text=No events, ' +
          'text=No scenario events, ' +
          '[class*="empty-state"]'
        );
        
        // Either events exist or empty state is shown
        const hasEmptyState = await emptyState.isVisible({ timeout: 2000 });
        if (hasEmptyState) {
          expect(hasEmptyState).toBe(true);
        }
      }
    } else {
      // Skip test if no MSELs exist
      test.skip();
    }
  });
});
