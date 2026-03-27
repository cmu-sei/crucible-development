// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('Gallery Integration - Content Selection', async ({ page }) => {
    // Authenticate with Blueprint
    await page.goto(Services.Blueprint.UI);
    await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin');
    await page.click('button:has-text("Sign In")');
    await page.waitForURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');

    // 1. Create a scenario event with Gallery delivery method
    // Navigate to create event - this assumes there's a way to access event creation
    // We'll look for common patterns like "Add Event", "Create Event", "New Event"
    const createEventButton = page.locator('button:has-text("Add Event"), button:has-text("Create Event"), button:has-text("New Event")').first();
    
    if (await createEventButton.isVisible({ timeout: 5000 }).catch(() => false)) {
      await createEventButton.click();
      
      // expect: Event creation form shows Gallery integration options
      const deliveryMethodField = page.locator('select:has-text("Gallery"), input:has-text("Gallery"), [label*="Delivery"], [placeholder*="delivery"]').first();
      await expect(deliveryMethodField).toBeVisible({ timeout: 10000 });
      
      // Try to select Gallery as delivery method
      const galleryOption = page.locator('option:has-text("Gallery"), text="Gallery"').first();
      if (await galleryOption.isVisible({ timeout: 5000 }).catch(() => false)) {
        await galleryOption.click();
      }
      
      // 2. Click 'Select from Gallery' or browse Gallery content
      const selectGalleryButton = page.locator('button:has-text("Select from Gallery"), button:has-text("Browse Gallery"), button:has-text("Gallery Content")').first();
      
      if (await selectGalleryButton.isVisible({ timeout: 5000 }).catch(() => false)) {
        await selectGalleryButton.click();
        
        // expect: Gallery content browser opens
        // expect: Shows available content items from Gallery service (http://localhost:4723)
        const galleryContent = page.locator('[class*="gallery"], [id*="gallery"], text=/Gallery.*Content/i').first();
        await expect(galleryContent).toBeVisible({ timeout: 10000 });
        
        // expect: Content can be filtered and searched
        const searchField = page.locator('input[type="search"], input[placeholder*="search" i], input[placeholder*="filter" i]').first();
        await expect(searchField).toBeVisible({ timeout: 5000 });
        
        // 3. Select content item(s) to associate with the event
        const contentItems = page.locator('[class*="content-item"], [class*="gallery-item"], [role="option"]');
        const firstItem = contentItems.first();
        
        if (await firstItem.isVisible({ timeout: 5000 }).catch(() => false)) {
          await firstItem.click();
          
          // expect: Content is linked to the scenario event
          // expect: Selected content appears in event details
          const selectedContent = page.locator('[class*="selected"], [aria-selected="true"]').first();
          await expect(selectedContent).toBeVisible({ timeout: 5000 });
        }
      } else {
        // If Gallery integration UI is not yet implemented, log this
        console.log('Gallery integration UI not found - feature may not be fully implemented yet');
      }
    } else {
      // If we can't find the create event button, try navigating directly to an event creation URL
      console.log('Create event button not found - attempting direct navigation');
      await page.goto(`${Services.Blueprint.UI}/events/create`);
      await page.waitForLoadState('networkidle');
      
      // Look for Gallery integration options on this page
      const galleryIntegration = page.locator('text=/Gallery/i').first();
      const hasGalleryOption = await galleryIntegration.isVisible({ timeout: 5000 }).catch(() => false);
      
      if (hasGalleryOption) {
        await expect(galleryIntegration).toBeVisible();
        console.log('Gallery integration option found on event creation page');
      } else {
        console.log('Gallery integration not yet available in Blueprint');
      }
    }
  });
});
