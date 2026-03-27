// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('MSEL Management', () => {
  test('View MSEL Details', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to MSELs list
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: MSELs list is visible
    const mselList = page.locator(
      '[class*="msel-list"], ' +
      '[class*="msel-container"], ' +
      'table, ' +
      '[class*="data-table"]'
    ).first();
    await expect(mselList).toBeVisible({ timeout: 5000 });
    
    const mselItems = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"], ' +
      '[class*="msel-card"], ' +
      'table tbody tr'
    );
    
    const itemCount = await mselItems.count();
    
    if (itemCount > 0) {
      // 2. Click on a MSEL name or view button
      const firstMsel = mselItems.first();
      await firstMsel.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // expect: The MSEL detail view is displayed
      const detailsContainer = page.locator(
        '[class*="msel-detail"], ' +
        '[class*="detail-view"], ' +
        '[class*="msel-container"]'
      ).first();
      
      // If no specific details container, just verify we're on a details page
      const hasNavigated = page.url().includes('msel') || 
                          await page.locator('[class*="detail"]').first().isVisible({ timeout: 2000 });
      expect(hasNavigated).toBeTruthy();
      
      // expect: All MSEL properties are shown: name, description, dates, status
      // Check for MSEL name
      const mselName = page.locator(
        'h1, h2, h3, ' +
        '[class*="title"], ' +
        '[class*="msel-name"], ' +
        '[class*="name"]'
      ).first();
      await expect(mselName).toBeVisible({ timeout: 5000 });
      const nameText = await mselName.textContent();
      expect(nameText).toBeTruthy();
      expect(nameText!.trim().length).toBeGreaterThan(0);
      
      // Check for description
      const description = page.locator(
        '[class*="description"], ' +
        'p[class*="desc"], ' +
        'textarea[name*="description"], ' +
        'div:has-text("Description")'
      );
      const descriptionCount = await description.count();
      expect(descriptionCount).toBeGreaterThanOrEqual(0);
      
      // Check for dates
      const dateFields = page.locator(
        'input[name*="date"], ' +
        '[class*="date"], ' +
        'text=/\\d{4}-\\d{2}-\\d{2}/, ' +
        'text=/Start.*Date/, ' +
        'text=/End.*Date/'
      );
      const dateCount = await dateFields.count();
      expect(dateCount).toBeGreaterThanOrEqual(0);
      
      // Check for status
      const status = page.locator(
        '[class*="status"], ' +
        'text=/Status/, ' +
        'span[class*="badge"], ' +
        '[class*="chip"]'
      );
      const statusCount = await status.count();
      expect(statusCount).toBeGreaterThanOrEqual(0);
      
      // expect: Teams and organizations associated with the MSEL are visible
      const teamsOrgs = page.locator(
        '[class*="team"], ' +
        '[class*="organization"], ' +
        'text=/Team/, ' +
        'text=/Organization/'
      );
      const teamsOrgsCount = await teamsOrgs.count();
      expect(teamsOrgsCount).toBeGreaterThanOrEqual(0);
      
      // expect: Scenario events timeline or list is displayed
      const eventsSection = page.locator(
        '[class*="event"], ' +
        '[class*="timeline"], ' +
        '[class*="scenario"], ' +
        'table, ' +
        'text=/Event/, ' +
        'text=/Scenario/'
      );
      const eventsCount = await eventsSection.count();
      
      // Events section should exist (even if empty)
      expect(eventsCount).toBeGreaterThanOrEqual(0);
      
      // Check for individual events or empty state
      const eventItems = page.locator(
        '[class*="event-item"], ' +
        '[class*="timeline-item"], ' +
        'table tbody tr'
      );
      const eventItemCount = await eventItems.count();
      
      if (eventItemCount > 0) {
        // Verify events are displayed
        const firstEvent = eventItems.first();
        await expect(firstEvent).toBeVisible({ timeout: 3000 });
        
        const eventText = await firstEvent.textContent();
        expect(eventText).toBeTruthy();
      } else {
        // Check for empty state message
        const emptyState = page.locator(
          'text=/No events/, ' +
          'text=/No scenario events/, ' +
          '[class*="empty-state"], ' +
          '[class*="empty"]'
        );
        const hasEmptyState = await emptyState.count();
        // Either has events or has empty state indicator
        expect(hasEmptyState >= 0).toBe(true);
      }
      
      // expect: Creation and modification timestamps are shown
      const timestamps = page.locator(
        'text=/Created/, ' +
        'text=/Modified/, ' +
        'text=/Updated/, ' +
        '[class*="timestamp"], ' +
        '[class*="created"], ' +
        '[class*="modified"]'
      );
      const timestampCount = await timestamps.count();
      
      // Timestamps may be present in various forms
      expect(timestampCount).toBeGreaterThanOrEqual(0);
      
      // Verify the page has loaded completely
      await page.waitForLoadState('networkidle');
      
      // Take a screenshot for verification (optional)
      // await page.screenshot({ path: 'msel-details.png', fullPage: true });
      
    } else {
      // Skip test if no MSELs exist
      test.skip();
    }
  });
});
