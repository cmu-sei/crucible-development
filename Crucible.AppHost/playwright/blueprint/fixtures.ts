import { test as base, Page } from '@playwright/test';
import { Services, authenticateWithKeycloak } from '../shared-fixtures';

/**
 * Blueprint-specific fixtures
 * Extends shared fixtures with Blueprint authentication
 */

/**
 * Blueprint-specific authentication helper
 * @param page - Playwright Page object
 * @param username - Keycloak username (default: 'admin')
 * @param password - Keycloak password (default: 'admin')
 */
export async function authenticateBlueprintWithKeycloak(
  page: Page,
  username: string = 'admin',
  password: string = 'admin'
): Promise<void> {
  await authenticateWithKeycloak(page, Services.Blueprint.UI, username, password);
}

/**
 * Blueprint-specific fixtures
 */
export type BlueprintFixtures = {
  blueprintAuthenticatedPage: Page;
};

/**
 * Extended test with Blueprint-specific fixtures
 */
export const test = base.extend<BlueprintFixtures>({
  blueprintAuthenticatedPage: async ({ page }, use) => {
    await authenticateBlueprintWithKeycloak(page);
    await use(page);
  },
});

export { expect } from '@playwright/test';
export { Services };
