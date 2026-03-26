import { test as base, expect } from '@playwright/test';

/**
 * Custom fixtures for Crucible testing
 */
export type CrucibleFixtures = {
  authenticatedPage: any;
  aspireDashboard: string;
};

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
};

/**
 * Keycloak authentication helper
 */
export async function authenticateWithKeycloak(
  page: any,
  username: string = 'admin',
  password: string = 'admin'
) {
  // Start from a service that requires auth (Player UI)
  await page.goto(Services.Player.UI);

  // Wait for Keycloak redirect
  await page.waitForURL(/.*localhost:8443.*/, { timeout: 10000 });

  // Fill in credentials
  await page.fill('input[name="username"]', username);
  await page.fill('input[name="password"]', password);

  // Submit login form (button with text "Sign In")
  await page.click('button:has-text("Sign In")');

  // Wait for redirect back to application
  await page.waitForURL(/.*localhost:4301.*/, { timeout: 10000 });
}

/**
 * Wait for Aspire services to be healthy
 */
export async function waitForAspireServices(
  page: any,
  requiredServices: string[] = ['keycloak', 'postgres']
) {
  // Navigate to Aspire dashboard
  await page.goto(Services.AspireDashboard);

  // Wait for dashboard to load
  await page.waitForSelector('[data-resource-name]', { timeout: 30000 });

  // Check that required services are running
  for (const service of requiredServices) {
    const serviceRow = page.locator(`[data-resource-name="${service}"]`);
    await expect(serviceRow).toBeVisible({ timeout: 60000 });

    // Check for "Running" or "Healthy" state
    const stateCell = serviceRow.locator('[data-state]');
    await expect(stateCell).toHaveAttribute('data-state', /Running|Healthy/i, { timeout: 60000 });
  }
}

/**
 * Extended test with Crucible fixtures
 */
export const test = base.extend<CrucibleFixtures>({
  aspireDashboard: async ({}, use) => {
    await use(Services.AspireDashboard);
  },

  authenticatedPage: async ({ page }, use) => {
    // This fixture provides a page that is already authenticated
    await authenticateWithKeycloak(page);
    await use(page);
  },
});

export { expect };
