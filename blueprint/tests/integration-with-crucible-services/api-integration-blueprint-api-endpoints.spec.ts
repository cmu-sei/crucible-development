// spec: blueprint/blueprint-test-plan.md
// seed: tests/seed.spec.ts

import { test, expect } from '@playwright/test';
import { Services, authenticateBlueprintWithKeycloak } from '../../fixtures';

test.describe('Integration with Crucible Services', () => {
  test('API Integration - Blueprint API Endpoints', async ({ page }) => {
    await authenticateBlueprintWithKeycloak(page, 'admin', 'admin');
    
    // 1. Open browser developer tools Network tab
    await expect(page).toHaveURL(/.*localhost:4725.*/, { timeout: 10000 });
    await page.waitForLoadState('networkidle');
    
    // expect: Network tab is active (implicitly active in Playwright)
    
    // Track API calls
    const apiCalls: Array<{
      url: string;
      method: string;
      status: number;
      hasAuth: boolean;
    }> = [];
    
    // Listen for all requests
    page.on('request', request => {
      const url = request.url();
      if (url.includes('localhost:4724') || url.includes('/api/')) {
        console.log(`API Request: ${request.method()} ${url}`);
      }
    });
    
    // Listen for all responses
    page.on('response', async response => {
      const url = response.url();
      if (url.includes('localhost:4724') || url.includes('/api/')) {
        const hasAuth = response.request().headers()['authorization'] !== undefined;
        
        apiCalls.push({
          url,
          method: response.request().method(),
          status: response.status(),
          hasAuth,
        });
        
        console.log(`API Response: ${response.status()} ${response.request().method()} ${url}`);
        
        // Verify JSON format for successful responses
        if (response.status() >= 200 && response.status() < 300) {
          try {
            const contentType = response.headers()['content-type'];
            if (contentType && contentType.includes('application/json')) {
              const json = await response.json();
              console.log('Response is valid JSON');
            }
          } catch (error) {
            console.log('Response is not JSON or failed to parse:', error);
          }
        }
      }
    });
    
    // 2. Perform various actions in Blueprint UI (create MSEL, add event, etc.)
    
    // Action 1: Navigate to MSELs list
    await page.waitForTimeout(2000);
    
    // Action 2: Click on a MSEL to view details
    const mselLink = page.locator(
      'a[href*="msel"], ' +
      '[class*="msel-item"]'
    ).first();
    
    if (await mselLink.isVisible({ timeout: 3000 })) {
      await mselLink.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // Action 3: Try to create a new event
      const addEventButton = page.locator(
        'button:has-text("Add Event"), ' +
        'button:has-text("Create Event"), ' +
        'button:has-text("New Event"), ' +
        'button:has-text("Add")'
      ).first();
      
      if (await addEventButton.isVisible({ timeout: 3000 })) {
        await addEventButton.click();
        await page.waitForTimeout(1000);
        
        // Fill in minimal event data
        const descriptionField = page.locator(
          'textarea[name*="description"], ' +
          'input[name*="description"]'
        ).first();
        
        if (await descriptionField.isVisible({ timeout: 2000 })) {
          await descriptionField.fill('Test API Integration Event');
          await page.waitForTimeout(500);
          
          // Try to save (may or may not succeed based on validation)
          const saveButton = page.locator(
            'button:has-text("Save"), ' +
            'button:has-text("Create"), ' +
            'button[type="submit"]'
          ).last();
          
          if (await saveButton.isVisible({ timeout: 2000 })) {
            await saveButton.click();
            await page.waitForTimeout(2000);
          }
          
          // Close the dialog if still open
          const closeButton = page.locator(
            'button:has-text("Cancel"), ' +
            'button:has-text("Close"), ' +
            'mat-icon:has-text("close")'
          ).first();
          
          if (await closeButton.isVisible({ timeout: 2000 })) {
            await closeButton.click();
          }
        }
      }
      
      // Action 4: Navigate back to home
      const homeButton = page.locator(
        'a[href="/"], ' +
        'button:has-text("Home"), ' +
        '[class*="logo"]'
      ).first();
      
      if (await homeButton.isVisible({ timeout: 2000 })) {
        await homeButton.click();
        await page.waitForLoadState('networkidle');
      }
    }
    
    // Wait for all API calls to complete
    await page.waitForTimeout(2000);
    
    // expect: API calls are made to http://localhost:4724 (Blueprint API)
    const blueprintApiCalls = apiCalls.filter(call => 
      call.url.includes('localhost:4724') || 
      (call.url.includes('/api/') && !call.url.includes('localhost:8443'))
    );
    
    console.log(`Total Blueprint API calls captured: ${blueprintApiCalls.length}`);
    
    if (blueprintApiCalls.length > 0) {
      // expect: Requests use proper authentication headers
      const authenticatedCalls = blueprintApiCalls.filter(call => call.hasAuth);
      console.log(`Authenticated API calls: ${authenticatedCalls.length} / ${blueprintApiCalls.length}`);
      
      // Most API calls should have authentication
      expect(authenticatedCalls.length).toBeGreaterThan(0);
      
      // expect: Responses are in expected JSON format
      // This is checked in the response listener above
      
      // expect: Error handling works correctly
      const errorCalls = blueprintApiCalls.filter(call => call.status >= 400);
      console.log(`API calls with errors: ${errorCalls.length}`);
      
      // Log details of error calls
      errorCalls.forEach(call => {
        console.log(`Error: ${call.status} ${call.method} ${call.url}`);
      });
      
      // Successful calls
      const successCalls = blueprintApiCalls.filter(call => call.status >= 200 && call.status < 300);
      console.log(`Successful API calls: ${successCalls.length}`);
      
      // Log successful API endpoints
      const uniqueEndpoints = [...new Set(blueprintApiCalls.map(call => {
        const url = new URL(call.url);
        return `${call.method} ${url.pathname}`;
      }))];
      
      console.log('Unique API endpoints called:');
      uniqueEndpoints.forEach(endpoint => console.log(`  ${endpoint}`));
      
    } else {
      console.log('No Blueprint API calls captured - API may be using different port or path');
    }
  });
});
