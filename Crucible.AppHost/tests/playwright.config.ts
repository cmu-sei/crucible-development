import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Crucible platform testing
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './tests',

  /* Run tests in files in parallel */
  fullyParallel: false,

  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,

  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,

  /* Opt out of parallel tests for sequential setup */
  workers: 1,

  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],

  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:4301',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Take screenshot only on failure */
    screenshot: 'only-on-failure',

    /* Video on failure */
    video: 'retain-on-failure',

    /* Timeout for each action (e.g., click, fill) */
    actionTimeout: 10000,

    /* Ignore HTTPS errors (for self-signed certs in dev) */
    ignoreHTTPSErrors: true,
  },

  /* Configure global timeout */
  timeout: 90000,

  /* Configure expect timeout */
  expect: {
    timeout: 10000,
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
      use: {
        ...devices['Desktop Firefox'],
      },
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: '.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],

  /* Run your local dev server before starting the tests */
  // Note: Aspire should already be running via `aspire run`
  // Uncomment below if you want Playwright to manage Aspire startup
  // webServer: {
  //   command: 'aspire run',
  //   url: 'http://localhost:18888',
  //   reuseExistingServer: !process.env.CI,
  //   timeout: 120000,
  // },
});
