// spec: specs/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Accessibility and Usability', () => {
  test.beforeEach(async ({ page }) => {
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

  test('Color Contrast Compliance', async ({ page }) => {
    // Helper function to calculate relative luminance
    const getRelativeLuminance = (rgb: number[]): number => {
      const [r, g, b] = rgb.map((val) => {
        val = val / 255;
        return val <= 0.03928 ? val / 12.92 : Math.pow((val + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };

    // Helper function to calculate contrast ratio
    const getContrastRatio = (rgb1: number[], rgb2: number[]): number => {
      const l1 = getRelativeLuminance(rgb1);
      const l2 = getRelativeLuminance(rgb2);
      const lighter = Math.max(l1, l2);
      const darker = Math.min(l1, l2);
      return (lighter + 0.05) / (darker + 0.05);
    };

    // Helper function to parse RGB color
    const parseRgb = (color: string): number[] => {
      const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      return match ? [parseInt(match[1]), parseInt(match[2]), parseInt(match[3])] : [0, 0, 0];
    };

    // 1. Navigate through different pages and components
    await expect(page).toHaveURL(/.*localhost:4725.*/);

    // 2. Check text color contrast against backgrounds
    // Check topbar contrast (#2d69b4 background with white text)
    const topbar = await page.locator('mat-toolbar, [role="banner"], header').first();
    if (await topbar.count() > 0) {
      const topbarBg = await topbar.evaluate((el) => {
        return window.getComputedStyle(el).backgroundColor;
      });
      const topbarColor = await topbar.evaluate((el) => {
        return window.getComputedStyle(el).color;
      });
      
      const bgRgb = parseRgb(topbarBg);
      const colorRgb = parseRgb(topbarColor);
      const contrastRatio = getContrastRatio(bgRgb, colorRgb);
      
      // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
      expect(contrastRatio).toBeGreaterThanOrEqual(3.0);
    }

    // Check body text contrast
    const bodyText = await page.locator('body, main, [role="main"]').first();
    const bodyBg = await bodyText.evaluate((el) => {
      return window.getComputedStyle(el).backgroundColor;
    });
    const bodyColor = await bodyText.evaluate((el) => {
      return window.getComputedStyle(el).color;
    });
    
    const bodyBgRgb = parseRgb(bodyBg);
    const bodyColorRgb = parseRgb(bodyColor);
    const bodyContrastRatio = getContrastRatio(bodyBgRgb, bodyColorRgb);
    
    // Body text should meet WCAG AA standard (4.5:1)
    expect(bodyContrastRatio).toBeGreaterThanOrEqual(4.5);

    // Check button contrast
    const buttons = await page.locator('button').all();
    for (const button of buttons.slice(0, 3)) { // Check first 3 buttons
      const isVisible = await button.isVisible().catch(() => false);
      if (!isVisible) continue;

      const btnBg = await button.evaluate((el) => {
        return window.getComputedStyle(el).backgroundColor;
      });
      const btnColor = await button.evaluate((el) => {
        return window.getComputedStyle(el).color;
      });
      
      const btnBgRgb = parseRgb(btnBg);
      const btnColorRgb = parseRgb(btnColor);
      
      // Skip if background is transparent
      if (btnBg.includes('rgba') && btnBg.includes('0)')) continue;
      
      const btnContrastRatio = getContrastRatio(btnBgRgb, btnColorRgb);
      
      // Buttons should meet WCAG AA standard
      expect(btnContrastRatio).toBeGreaterThanOrEqual(3.0);
    }

    // Check link contrast
    const links = await page.locator('a').all();
    for (const link of links.slice(0, 3)) { // Check first 3 links
      const isVisible = await link.isVisible().catch(() => false);
      if (!isVisible) continue;

      const linkColor = await link.evaluate((el) => {
        return window.getComputedStyle(el).color;
      });
      
      const parentBg = await link.evaluate((el) => {
        let parent = el.parentElement;
        while (parent) {
          const bg = window.getComputedStyle(parent).backgroundColor;
          if (bg && !bg.includes('rgba(0, 0, 0, 0)')) {
            return bg;
          }
          parent = parent.parentElement;
        }
        return 'rgb(255, 255, 255)';
      });
      
      const linkColorRgb = parseRgb(linkColor);
      const parentBgRgb = parseRgb(parentBg);
      const linkContrastRatio = getContrastRatio(linkColorRgb, parentBgRgb);
      
      // Links should meet WCAG AA standard
      expect(linkContrastRatio).toBeGreaterThanOrEqual(4.5);
    }

    // Test both light and dark themes
    // Try to find theme toggle
    const themeToggle = await page.locator('button[aria-label*="theme" i], button[title*="theme" i], button:has-text("Theme")').first();
    if (await themeToggle.count() > 0) {
      await themeToggle.click();
      await page.waitForTimeout(1000); // Wait for theme transition
      
      // Re-check contrast ratios in the new theme
      const newBodyBg = await bodyText.evaluate((el) => {
        return window.getComputedStyle(el).backgroundColor;
      });
      const newBodyColor = await bodyText.evaluate((el) => {
        return window.getComputedStyle(el).color;
      });
      
      const newBodyBgRgb = parseRgb(newBodyBg);
      const newBodyColorRgb = parseRgb(newBodyColor);
      const newBodyContrastRatio = getContrastRatio(newBodyBgRgb, newBodyColorRgb);
      
      expect(newBodyContrastRatio).toBeGreaterThanOrEqual(4.5);
    }
  });
});
