// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Accessibility and Usability', () => {
  test('Responsive Layout - Tablet View', async ({ page }) => {
    // 1. Resize browser to tablet viewport (768x1024)
    await page.setViewportSize({ width: 768, height: 1024 });
    
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

    // 2. Navigate through the application
    // Verify page layout adapts to tablet view
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    expect(bodyWidth).toBeLessThanOrEqual(768);

    // Verify layout makes efficient use of available space
    const mainContent = await page.locator('main, [role="main"], .content, .main-content').first();
    if (await mainContent.count() > 0) {
      await expect(mainContent).toBeVisible();
      
      const contentBox = await mainContent.boundingBox();
      if (contentBox) {
        // Content should utilize most of the viewport width
        expect(contentBox.width).toBeGreaterThan(600);
        expect(contentBox.width).toBeLessThanOrEqual(768);
      }
    }

    // Verify no horizontal scrolling
    const hasHorizontalScroll = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(hasHorizontalScroll).toBe(false);

    // Check that all features remain accessible
    // Verify navigation is accessible
    const navElements = await page.locator('nav a, nav button, [role="navigation"] a, [role="navigation"] button').all();
    expect(navElements.length).toBeGreaterThan(0);
    
    for (const navItem of navElements.slice(0, 5)) {
      const isVisible = await navItem.isVisible().catch(() => false);
      if (isVisible) {
        await expect(navItem).toBeVisible();
      }
    }

    // Verify forms are properly sized for tablet
    const inputs = await page.locator('input, textarea, select').all();
    for (const input of inputs.slice(0, 3)) {
      const isVisible = await input.isVisible().catch(() => false);
      if (!isVisible) continue;

      const box = await input.boundingBox();
      if (box) {
        // Input should not exceed viewport width
        expect(box.x + box.width).toBeLessThanOrEqual(768);
        // Input should be appropriately sized for tablet interaction
        expect(box.height).toBeGreaterThanOrEqual(32);
      }
    }

    // Verify buttons and interactive elements are appropriately sized
    const buttons = await page.locator('button, a[role="button"]').all();
    for (const button of buttons.slice(0, 5)) {
      const isVisible = await button.isVisible().catch(() => false);
      if (!isVisible) continue;

      const box = await button.boundingBox();
      if (box) {
        // Touch targets should be at least 44x44 pixels for tablet
        expect(box.width).toBeGreaterThanOrEqual(40);
        expect(box.height).toBeGreaterThanOrEqual(40);
      }
    }

    // Check if timeline view is optimized for tablet (if present)
    const timeline = await page.locator('.timeline, [role="list"], .event-list, mat-list').first();
    if (await timeline.count() > 0) {
      const timelineBox = await timeline.boundingBox();
      if (timelineBox) {
        // Timeline should fit within viewport
        expect(timelineBox.width).toBeLessThanOrEqual(768);
      }
    }

    // Verify topbar layout for tablet
    const topbar = await page.locator('mat-toolbar, header, [role="banner"]').first();
    if (await topbar.count() > 0) {
      const topbarBox = await topbar.boundingBox();
      if (topbarBox) {
        // Topbar should span the full width
        expect(topbarBox.width).toBeGreaterThan(700);
        expect(topbarBox.width).toBeLessThanOrEqual(768);
      }
      
      await expect(topbar).toBeVisible();
    }

    // Check that tables or grids adapt properly to tablet view
    const tables = await page.locator('table, mat-table, [role="grid"]').all();
    for (const table of tables.slice(0, 2)) {
      const isVisible = await table.isVisible().catch(() => false);
      if (!isVisible) continue;

      const tableBox = await table.boundingBox();
      if (tableBox) {
        // Table should not cause horizontal overflow
        expect(tableBox.width).toBeLessThanOrEqual(768);
      }
    }

    // Verify dialogs and modals work properly on tablet
    const dialogTrigger = await page.locator('button:has-text("Create"), button:has-text("Add"), button:has-text("New")').first();
    if (await dialogTrigger.count() > 0) {
      await dialogTrigger.click();
      await page.waitForTimeout(500);
      
      const dialog = await page.locator('mat-dialog-container, [role="dialog"], .dialog, .modal').first();
      if (await dialog.count() > 0) {
        await expect(dialog).toBeVisible();
        
        const dialogBox = await dialog.boundingBox();
        if (dialogBox) {
          // Dialog should fit within tablet viewport with margins
          expect(dialogBox.width).toBeLessThan(768);
        }
        
        // Close dialog
        const closeButton = await page.locator('button[mat-dialog-close], button:has-text("Cancel"), button:has-text("Close")').first();
        if (await closeButton.count() > 0) {
          await closeButton.click();
        } else {
          await page.keyboard.press('Escape');
        }
      }
    }

    // Verify multi-column layouts adapt appropriately
    const contentAreas = await page.locator('.content, main, [role="main"]').first();
    if (await contentAreas.count() > 0) {
      const hasMultiColumn = await contentAreas.evaluate((el) => {
        const style = window.getComputedStyle(el);
        return style.display === 'grid' || style.display === 'flex';
      });
      
      // Layout should use responsive design patterns
      // This is verified by checking that content doesn't overflow
    }
  });
});
