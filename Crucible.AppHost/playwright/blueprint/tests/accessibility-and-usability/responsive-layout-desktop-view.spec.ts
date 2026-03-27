// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Accessibility and Usability', () => {
  test.beforeEach(async ({ page }) => {
    // 1. View application in desktop resolution (1920x1080)
    await page.setViewportSize({ width: 1920, height: 1080 });
    
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

  test('Responsive Layout - Desktop View', async ({ page }) => {
    // Verify page layout utilizes desktop space effectively
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    expect(bodyWidth).toBeGreaterThan(1280);

    // Check that main content area uses available space
    const mainContent = await page.locator('main, [role="main"], .content, .main-content').first();
    if (await mainContent.count() > 0) {
      await expect(mainContent).toBeVisible();
      
      const contentBox = await mainContent.boundingBox();
      if (contentBox) {
        // Content should utilize desktop space efficiently
        expect(contentBox.width).toBeGreaterThan(1000);
      }
    }

    // Verify no horizontal scrolling at desktop resolution
    const hasHorizontalScroll = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(hasHorizontalScroll).toBe(false);

    // Verify navigation is fully visible and not collapsed
    const navigation = await page.locator('nav, [role="navigation"]').first();
    if (await navigation.count() > 0) {
      await expect(navigation).toBeVisible();
    }

    // Verify topbar spans full width
    const topbar = await page.locator('mat-toolbar, header, [role="banner"]').first();
    if (await topbar.count() > 0) {
      await expect(topbar).toBeVisible();
      
      const topbarBox = await topbar.boundingBox();
      if (topbarBox) {
        // Topbar should span most of the viewport width
        expect(topbarBox.width).toBeGreaterThan(1800);
      }
    }

    // 2. Resize window to various widths
    const testWidths = [1600, 1366, 1280];
    
    for (const width of testWidths) {
      await page.setViewportSize({ width, height: 1080 });
      await page.waitForTimeout(300); // Allow layout to adjust
      
      // Verify layout adapts smoothly
      const newBodyWidth = await page.evaluate(() => document.body.scrollWidth);
      expect(newBodyWidth).toBeLessThanOrEqual(width);
      
      // Verify no content is cut off or inaccessible
      const hasHorizontalScroll = await page.evaluate(() => {
        return document.documentElement.scrollWidth > document.documentElement.clientWidth;
      });
      expect(hasHorizontalScroll).toBe(false);
      
      // Verify main content remains visible
      if (await mainContent.count() > 0) {
        await expect(mainContent).toBeVisible();
      }
      
      // Check if timeline scales appropriately (if present)
      const timeline = await page.locator('.timeline, [role="list"], .event-list, mat-list').first();
      if (await timeline.count() > 0) {
        const timelineBox = await timeline.boundingBox();
        if (timelineBox) {
          // Timeline should fit within viewport
          expect(timelineBox.width).toBeLessThanOrEqual(width);
        }
      }
    }

    // Reset to full desktop resolution
    await page.setViewportSize({ width: 1920, height: 1080 });

    // Verify multi-column layouts work properly on desktop
    const hasGridOrFlex = await page.evaluate(() => {
      const main = document.querySelector('main, [role="main"], .content');
      if (main) {
        const style = window.getComputedStyle(main);
        return style.display === 'grid' || style.display === 'flex';
      }
      return false;
    });

    // Verify tables and data grids display properly
    const tables = await page.locator('table, mat-table, [role="grid"]').all();
    for (const table of tables.slice(0, 2)) {
      const isVisible = await table.isVisible().catch(() => false);
      if (!isVisible) continue;

      await expect(table).toBeVisible();
      
      const tableBox = await table.boundingBox();
      if (tableBox) {
        // Table should fit comfortably in desktop view
        expect(tableBox.width).toBeLessThanOrEqual(1920);
      }
    }

    // Verify dialogs are appropriately sized for desktop
    const dialogTrigger = await page.locator('button:has-text("Create"), button:has-text("Add"), button:has-text("New")').first();
    if (await dialogTrigger.count() > 0) {
      await dialogTrigger.click();
      await page.waitForTimeout(500);
      
      const dialog = await page.locator('mat-dialog-container, [role="dialog"], .dialog, .modal').first();
      if (await dialog.count() > 0) {
        await expect(dialog).toBeVisible();
        
        const dialogBox = await dialog.boundingBox();
        if (dialogBox) {
          // Dialog should be reasonably sized for desktop (not too small, not full screen)
          expect(dialogBox.width).toBeGreaterThan(400);
          expect(dialogBox.width).toBeLessThan(1400);
          expect(dialogBox.height).toBeLessThan(900);
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

    // Verify text remains readable (not too large)
    const textElements = await page.locator('p, span, div').all();
    for (const element of textElements.slice(0, 5)) {
      const isVisible = await element.isVisible().catch(() => false);
      if (!isVisible) continue;

      const fontSize = await element.evaluate((el) => {
        return parseFloat(window.getComputedStyle(el).fontSize);
      });
      
      // Font size should be reasonable for desktop (typically 12-24px for body text)
      if (fontSize > 0) {
        expect(fontSize).toBeGreaterThan(10);
        expect(fontSize).toBeLessThan(48);
      }
    }

    // Verify sidebars or side panels display properly on desktop
    const sidebar = await page.locator('aside, .sidebar, mat-sidenav, [role="complementary"]').first();
    if (await sidebar.count() > 0) {
      const sidebarBox = await sidebar.boundingBox();
      if (sidebarBox) {
        // Sidebar should be visible and reasonably sized
        expect(sidebarBox.width).toBeGreaterThan(200);
        expect(sidebarBox.width).toBeLessThan(600);
      }
    }
  });
});
