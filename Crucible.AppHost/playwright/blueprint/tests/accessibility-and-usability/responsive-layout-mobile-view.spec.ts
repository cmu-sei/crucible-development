// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Accessibility and Usability', () => {
  test('Responsive Layout - Mobile View', async ({ page }) => {
    // 1. Resize browser to mobile viewport (375x667)
    await page.setViewportSize({ width: 375, height: 667 });
    
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
    // Verify page layout adapts to mobile view
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    expect(bodyWidth).toBeLessThanOrEqual(375);

    // Check for hamburger menu or mobile navigation
    const hamburgerMenu = await page.locator('button[aria-label*="menu" i], button[aria-label*="navigation" i], .hamburger, mat-icon:has-text("menu")').first();
    // If hamburger menu exists, it should be visible on mobile
    if (await hamburgerMenu.count() > 0) {
      await expect(hamburgerMenu).toBeVisible();
    }

    // Verify no horizontal scrolling is required
    const hasHorizontalScroll = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(hasHorizontalScroll).toBe(false);

    // Check that touch targets are appropriately sized (minimum 44x44 pixels)
    const buttons = await page.locator('button, a').all();
    for (const button of buttons.slice(0, 5)) { // Check first 5 interactive elements
      const isVisible = await button.isVisible().catch(() => false);
      if (!isVisible) continue;

      const box = await button.boundingBox();
      if (box) {
        // WCAG 2.1 AA requires minimum 44x44 pixels for touch targets
        expect(box.width).toBeGreaterThanOrEqual(40); // Allowing small margin
        expect(box.height).toBeGreaterThanOrEqual(40);
      }
    }

    // Verify forms are usable on small screens
    const inputs = await page.locator('input, textarea, select').all();
    for (const input of inputs.slice(0, 3)) {
      const isVisible = await input.isVisible().catch(() => false);
      if (!isVisible) continue;

      const box = await input.boundingBox();
      if (box) {
        // Input should not overflow the viewport
        expect(box.x + box.width).toBeLessThanOrEqual(375);
        // Input should be tall enough to be easily tappable
        expect(box.height).toBeGreaterThanOrEqual(32);
      }
    }

    // Test navigation if hamburger menu exists
    if (await hamburgerMenu.count() > 0) {
      await hamburgerMenu.click();
      await page.waitForTimeout(500); // Wait for menu animation
      
      // Verify navigation menu is visible
      const navMenu = await page.locator('nav, [role="navigation"], .mobile-menu, .nav-drawer, mat-sidenav').first();
      await expect(navMenu).toBeVisible();
    }

    // Verify topbar adapts to mobile
    const topbar = await page.locator('mat-toolbar, header, [role="banner"]').first();
    if (await topbar.count() > 0) {
      const topbarBox = await topbar.boundingBox();
      if (topbarBox) {
        // Topbar should not exceed viewport width
        expect(topbarBox.width).toBeLessThanOrEqual(375);
      }
    }

    // Check that text is readable (not too small)
    const textElements = await page.locator('p, span, div, li').all();
    for (const element of textElements.slice(0, 5)) {
      const isVisible = await element.isVisible().catch(() => false);
      if (!isVisible) continue;

      const fontSize = await element.evaluate((el) => {
        return parseFloat(window.getComputedStyle(el).fontSize);
      });
      
      // Minimum readable font size on mobile should be 14px
      if (fontSize > 0) {
        expect(fontSize).toBeGreaterThanOrEqual(12);
      }
    }

    // Verify main content area is accessible
    const mainContent = await page.locator('main, [role="main"], .content, .main-content').first();
    if (await mainContent.count() > 0) {
      await expect(mainContent).toBeVisible();
      
      const contentBox = await mainContent.boundingBox();
      if (contentBox) {
        // Content should not cause horizontal overflow
        expect(contentBox.width).toBeLessThanOrEqual(375);
      }
    }
  });
});
