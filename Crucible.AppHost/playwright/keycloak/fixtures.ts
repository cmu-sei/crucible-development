import { test as base, Page } from '@playwright/test';
import { Services } from '../shared-fixtures';

/**
 * Keycloak-specific fixtures
 * Tests for the Keycloak identity provider itself
 */

/**
 * Navigate to Keycloak admin console
 * @param page - Playwright Page object
 * @param username - Keycloak admin username (default: 'admin')
 * @param password - Keycloak admin password (default: 'admin')
 */
export async function authenticateKeycloakAdmin(
  page: Page,
  username: string = 'admin',
  password: string = 'admin'
): Promise<void> {
  console.log('Authenticating with Keycloak Admin Console...');

  // Navigate to Keycloak admin console
  await page.goto(`${Services.Keycloak}/admin`);

  // Wait for login page
  await page.waitForSelector('input[name="username"]', { timeout: 10000 });

  // Fill in credentials
  await page.fill('input[name="username"]', username);
  await page.fill('input[name="password"]', password);

  // Submit login form
  try {
    await page.click('button:has-text("Sign In")', { timeout: 2000 });
  } catch {
    await page.click('input[type="submit"]');
  }

  // Wait for admin console to load
  await page.waitForURL(/.*admin\/master\/console.*/, { timeout: 30000 });

  console.log('Successfully authenticated to Keycloak Admin Console');
}

/**
 * Navigate to Crucible realm
 * @param page - Playwright Page object
 */
export async function navigateToCrucibleRealm(page: Page): Promise<void> {
  // Select realm dropdown
  await page.click('[data-testid="realmSelector"]');

  // Click on Crucible realm
  await page.click('text=crucible');

  // Wait for realm to load
  await page.waitForURL(/.*\/realms\/crucible\/.*/, { timeout: 10000 });
}

/**
 * Keycloak-specific fixtures
 */
export type KeycloakFixtures = {
  keycloakAdminPage: Page;
  keycloakCrucibleRealmPage: Page;
};

/**
 * Extended test with Keycloak-specific fixtures
 */
export const test = base.extend<KeycloakFixtures>({
  keycloakAdminPage: async ({ page }, use) => {
    await authenticateKeycloakAdmin(page);
    await use(page);
  },

  keycloakCrucibleRealmPage: async ({ page }, use) => {
    await authenticateKeycloakAdmin(page);
    await navigateToCrucibleRealm(page);
    await use(page);
  },
});

export { expect } from '@playwright/test';
export { Services };
