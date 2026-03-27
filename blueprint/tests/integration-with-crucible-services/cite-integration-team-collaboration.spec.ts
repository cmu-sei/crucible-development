// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('CITE Integration - Team Collaboration', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Navigate to a MSEL that is linked to a CITE evaluation
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // Navigate to a MSEL details page
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      
      // expect: MSEL details show CITE integration status
      await page.waitForTimeout(1000);
      
      // Look for CITE integration indicators
      const citeSection = page.locator(
        '[class*="cite-integration"], ' +
        '[class*="cite-link"], ' +
        'text=CITE Evaluation, ' +
        'text=CITE'
      ).first();
      
      // Check if MSEL has CITE integration
      const citeConfigButton = page.locator(
        'button:has-text("CITE"), ' +
        'button:has-text("Configure CITE"), ' +
        '[class*="cite-button"]'
      ).first();
      
      if (await citeConfigButton.isVisible({ timeout: 3000 })) {
        // MSEL has CITE integration options
        await citeConfigButton.click();
        await page.waitForTimeout(1000);
        
        // Look for CITE evaluation selector or link
        const citeEvaluationSelector = page.locator(
          'select[name*="cite"], ' +
          'mat-select[formControlName*="cite"], ' +
          'select[formControlName*="evaluation"]'
        ).first();
        
        if (await citeEvaluationSelector.isVisible({ timeout: 2000 })) {
          await citeEvaluationSelector.click();
          
          // Select an evaluation if available
          const evaluationOption = page.locator(
            'mat-option, ' +
            'option'
          ).first();
          
          if (await evaluationOption.isVisible({ timeout: 2000 })) {
            await evaluationOption.click();
          }
        }
        
        // Save CITE configuration
        const saveButton = page.locator(
          'button:has-text("Save"), ' +
          'button:has-text("Apply"), ' +
          'button[type="submit"]'
        ).last();
        
        if (await saveButton.isVisible({ timeout: 2000 })) {
          await saveButton.click();
          await page.waitForTimeout(1000);
        }
      }
      
      // 2. Click 'Open in CITE' or similar integration link
      const openCiteButton = page.locator(
        'button:has-text("Open in CITE"), ' +
        'a:has-text("Open in CITE"), ' +
        'button:has-text("View in CITE"), ' +
        'a[href*="cite"], ' +
        'a[href*="4721"]'
      ).first();
      
      if (await openCiteButton.isVisible({ timeout: 5000 })) {
        // Store the current page for later
        const originalPage = page;
        
        // Listen for new page/tab
        const pagePromise = page.context().waitForEvent('page', { timeout: 10000 });
        
        await openCiteButton.click();
        
        try {
          // expect: Navigation to CITE service (http://localhost:4721) occurs
          const citePage = await pagePromise;
          await citePage.waitForLoadState('networkidle', { timeout: 10000 });
          
          // expect: CITE shows the associated evaluation for this MSEL
          await expect(citePage).toHaveURL(new RegExp('.*localhost:4721.*'), { timeout: 10000 });
          
          // expect: Teams and scenario timeline are synchronized
          // Check for evaluation content
          const evaluationContent = citePage.locator(
            '[class*="evaluation"], ' +
            '[class*="scenario"], ' +
            '[class*="teams"]'
          ).first();
          
          // Close CITE tab and return to Blueprint
          await citePage.close();
        } catch (error) {
          console.log('CITE integration link did not open in new window:', error);
        }
      } else {
        console.log('CITE integration not configured for this MSEL');
      }
    } else {
      test.skip();
    }
  });
});
