import { test as base, expect as baseExpect, Page } from '@playwright/test';

/**
 * Shared fixtures for all Crucible applications
 * Provides common authentication helpers and service URL constants
 */

/**
 * Crucible service URLs
 */
export const Services = {
  AspireDashboard: 'http://localhost:18888',
  Keycloak: 'https://localhost:8443',
  KeycloakRealm: 'https://localhost:8443/realms/crucible',
  Player: {
    UI: 'http://localhost:4301',
    API: 'http://localhost:4302',
  },
  PlayerVM: {
    UI: 'http://localhost:4303',
    API: 'http://localhost:4304',
  },
  Console: {
    UI: 'http://localhost:4305',
  },
  Caster: {
    UI: 'http://localhost:4310',
    API: 'http://localhost:4311',
  },
  Alloy: {
    UI: 'http://localhost:4403',
    API: 'http://localhost:4402',
  },
  TopoMojo: {
    UI: 'http://localhost:4201',
    API: 'http://localhost:5000',
  },
  Steamfitter: {
    UI: 'http://localhost:4401',
    API: 'http://localhost:4400',
  },
  Cite: {
    UI: 'http://localhost:4721',
    API: 'http://localhost:4720',
  },
  Gallery: {
    UI: 'http://localhost:4723',
    API: 'http://localhost:4722',
  },
  Blueprint: {
    UI: 'http://localhost:4725',
    API: 'http://localhost:4724',
  },
  Gameboard: {
    UI: 'http://localhost:4202',
    API: 'http://localhost:4203',
  },
  Moodle: 'http://localhost:8081',
  Lrsql: 'http://localhost:9274',
  Misp: 'https://localhost:8444',
} as const;

/**
 * Generic Keycloak authentication helper
 * @param page - Playwright Page object
 * @param appUrl - The application URL to authenticate with
 * @param username - Keycloak username (default: 'admin')
 * @param password - Keycloak password (default: 'admin')
 */
export async function authenticateWithKeycloak(
  page: Page,
  appUrl: string,
  username: string = 'admin',
  password: string = 'admin'
): Promise<void> {
  console.log(`Authenticating with Keycloak for ${appUrl}...`);

  // Navigate to the application (will redirect to Keycloak)
  await page.goto(appUrl);

  // Wait for redirect to Keycloak login page
  await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });

  // Fill in Keycloak credentials
  await page.fill('input[name="username"]', username);
  await page.fill('input[name="password"]', password);

  // Submit login form (try both button text and input[type="submit"])
  try {
    await page.click('button:has-text("Sign In")', { timeout: 2000 });
  } catch {
    await page.click('input[type="submit"]');
  }

  // Wait for redirect back to the application using regex pattern
  const appUrlPattern = appUrl.replace('http://localhost:', '.*localhost:');
  await page.waitForURL(new RegExp(appUrlPattern), { timeout: 30000 });

  // Wait for page to be fully loaded
  await page.waitForLoadState('networkidle', { timeout: 30000 });

  console.log(`Successfully authenticated and returned to ${appUrl}`);
}

/**
 * Wait for Aspire services to be healthy
 * @param page - Playwright Page object
 * @param requiredServices - Array of service names to check (default: ['keycloak', 'postgres'])
 */
export async function waitForAspireServices(
  page: Page,
  requiredServices: string[] = ['keycloak', 'postgres']
): Promise<void> {
  // Navigate to Aspire dashboard
  await page.goto(Services.AspireDashboard);

  // Wait for dashboard to load
  await page.waitForSelector('[data-resource-name]', { timeout: 30000 });

  // Check that required services are running
  for (const service of requiredServices) {
    const serviceRow = page.locator(`[data-resource-name="${service}"]`);
    await baseExpect(serviceRow).toBeVisible({ timeout: 60000 });

    // Check for "Running" or "Healthy" state
    const stateCell = serviceRow.locator('[data-state]');
    await baseExpect(stateCell).toHaveAttribute('data-state', /Running|Healthy/i, { timeout: 60000 });
  }
}

/**
 * Check if a service is available at the specified URL
 * Useful for health checks before running tests
 * @param page - Playwright Page object
 * @param url - Service URL to check
 */
export async function checkServiceHealth(page: Page, url: string): Promise<boolean> {
  try {
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 5000 });
    return response?.ok() || false;
  } catch {
    return false;
  }
}

/**
 * Extended test with common fixtures
 * Apps can import this and extend it further with app-specific fixtures
 */
export const test = base.extend({});

export { expect } from '@playwright/test';
