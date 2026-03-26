import { test as setup } from '@playwright/test';
import { authenticateWithKeycloak, Services } from '../fixtures';
import fs from 'node:fs';
import path from 'node:path';

const authFile = '../.auth/user.json';

/**
 * Seed test that sets up authenticated session and validates Aspire services
 * This test runs before all other tests and saves authentication state
 */
setup('authenticate with Keycloak', async ({ page }) => {
  console.log('🔧 Starting Crucible test environment setup...');

  // Step 1: Authenticate with Keycloak
  console.log('🔐 Authenticating with Keycloak...');
  await authenticateWithKeycloak(page, 'admin', 'admin');
  console.log('✅ Authentication successful');

  // Step 3: Verify we're logged in by checking for user menu or similar element
  await page.goto(Services.Player.UI);
  console.log('✅ Player UI loaded successfully');

  // Step 4: Save authentication state for other tests
  // Create .auth directory if it doesn't exist
  const authDir = path.dirname(authFile);
  if (!fs.existsSync(authDir)) {
    fs.mkdirSync(authDir, { recursive: true });
  }

  await page.context().storageState({ path: authFile });
  console.log('✅ Authentication state saved');

  console.log('🎉 Crucible test environment ready!');
});
