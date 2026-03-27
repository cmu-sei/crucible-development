# Crucible Playwright Tests

Automated end-to-end tests for all Crucible applications using Playwright.

## Overview

This test suite provides comprehensive testing for the Crucible platform, organized by application:

- **Keycloak** - Identity provider and authentication (OIDC/SSO)
- **Blueprint** - MSEL (Master Scenario Events List) creation and management
- **Player** - Main learning platform interface
- **CITE** - Collaborative training and evaluation
- **Gameboard** - Competition and scoring platform
- **TopoMojo** - Network topology simulation
- **Steamfitter** - Scenario execution and automation
- **Moodle** - Learning Management System (LMS) integration
- **Alloy** - Advanced orchestration
- **Caster** - Infrastructure orchestration
- **Gallery** - Content management

## Prerequisites

Before you begin, ensure you have:

1. **.NET 8 SDK** - Required for running Aspire
   ```bash
   dotnet --version  # Should be 8.0.x or higher
   ```

2. **Node.js v18+** - Required for Playwright
   ```bash
   node --version  # Should be v18 or higher
   npm --version
   ```

3. **Git** - For cloning repositories
   ```bash
   git --version
   ```

## Directory Structure

```
playwright/
├── shared-fixtures.ts         # Shared authentication and utilities
├── playwright.config.ts       # Playwright configuration
├── setup.sh                   # Setup script
├── run-tests.sh              # Test runner script
├── keycloak/                 # Keycloak identity provider tests
│   ├── keycloak-test-plan.md
│   ├── fixtures.ts
│   ├── README.md
│   └── tests/
│       ├── authentication/
│       ├── user-management/
│       ├── realm-configuration/
│       └── client-management/
├── blueprint/                # Blueprint application tests
│   ├── blueprint-test-plan.md
│   ├── fixtures.ts
│   └── tests/
│       ├── authentication-and-authorization/
│       ├── home-page-and-navigation/
│       ├── msel-management/
│       └── scenario-events-management/
├── player/                   # Player application tests
├── cite/                     # CITE application tests
├── gameboard/                # Gameboard application tests
├── topomojo/                 # TopoMojo application tests
├── steamfitter/              # Steamfitter application tests
├── moodle/                   # Moodle application tests
├── alloy/                    # Alloy application tests
├── caster/                   # Caster application tests
└── gallery/                  # Gallery application tests
```

## Quick Start

### 1. Setup

Run the automated setup script:

```bash
cd /workspaces/crucible-development/Crucible.AppHost/playwright
chmod +x setup.sh
./setup.sh
```

This will:
- ✅ Check your environment
- ✅ Install npm dependencies
- ✅ Install Playwright browsers
- ✅ Verify service availability

**Manual Installation:**

If you prefer manual setup:

```bash
# Install dependencies
npm install

# Install Chromium (recommended)
npx playwright install chromium

# Or install all browsers
npx playwright install

# Install system dependencies (if needed)
npx playwright install-deps
```

### 2. Start Aspire Services

In a separate terminal:

```bash
cd /workspaces/crucible-development/Crucible.AppHost
dotnet run
```

Wait for all services to start. You'll see:
```
Now listening on: http://localhost:18888
```

### 3. Verify Services

Check that these services are accessible:
- 📊 Aspire Dashboard: http://localhost:18888
- 🔐 Keycloak: https://localhost:8443
- 🔵 Blueprint UI: http://localhost:4725

### 4. Run Your First Test

```bash
cd /workspaces/crucible-development/Crucible.AppHost/playwright

# Run a quick smoke test
./run-tests.sh quick

# Or run a specific test
npx playwright test blueprint/tests/authentication-and-authorization/user-login-flow.spec.ts
```

## Test Runner Commands

### Application-Specific Tests

```bash
# Run tests for specific applications
./run-tests.sh keycloak       # Identity provider
./run-tests.sh blueprint
./run-tests.sh player
./run-tests.sh cite
./run-tests.sh gameboard
./run-tests.sh topomojo
./run-tests.sh steamfitter
./run-tests.sh moodle
./run-tests.sh alloy
./run-tests.sh caster
./run-tests.sh gallery
```

### General Commands

```bash
# Run all tests
./run-tests.sh all

# Run all tests for a specific app
./run-tests.sh all --app blueprint

# Run smoke tests
./run-tests.sh quick                    # Default: Blueprint
./run-tests.sh quick --app player      # Specific app

# Interactive UI mode
./run-tests.sh ui                      # All apps
./run-tests.sh ui blueprint           # Specific app

# Headed mode (see browser)
./run-tests.sh headed blueprint

# Debug mode
./run-tests.sh debug blueprint

# Filter tests by pattern
./run-tests.sh all --filter login --app blueprint

# View test report
./run-tests.sh report

# Skip service health checks
./run-tests.sh blueprint --no-check
```

## Test Status by Application

| Application | Test Plan | Tests Generated | Status |
|-------------|-----------|-----------------|--------|
| Keycloak    | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Blueprint   | ✅ 100+ tests | ✅ 16 tests | 🟢 In Progress |
| Player      | ✅ Complete | 🔴 Not started | ⚪ Planned |
| CITE        | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Gameboard   | ✅ Complete | 🔴 Not started | ⚪ Planned |
| TopoMojo    | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Steamfitter | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Moodle      | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Alloy       | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Caster      | ✅ Complete | 🔴 Not started | ⚪ Planned |
| Gallery     | ✅ Complete | 🔴 Not started | ⚪ Planned |

## Service URLs Reference

| Service | UI Port | API Port | URL |
|---------|---------|----------|-----|
| Aspire Dashboard | 18888 | - | http://localhost:18888 |
| Keycloak | 8443 | - | https://localhost:8443 |
| Blueprint | 4725 | 4724 | http://localhost:4725 |
| Player | 4301 | 4302 | http://localhost:4301 |
| Player VM | 4303 | 4304 | http://localhost:4303 |
| Console | 4305 | - | http://localhost:4305 |
| Caster | 4310 | 4311 | http://localhost:4310 |
| Alloy | 4403 | 4402 | http://localhost:4403 |
| TopoMojo | 4201 | 5000 | http://localhost:4201 |
| Steamfitter | 4401 | 4400 | http://localhost:4401 |
| CITE | 4721 | 4720 | http://localhost:4721 |
| Gallery | 4723 | 4722 | http://localhost:4723 |
| Gameboard | 4202 | 4203 | http://localhost:4202 |
| Moodle | 8081 | - | http://localhost:8081 |
| LRsql | 9274 | - | http://localhost:9274 |
| MISP | 8444 | - | https://localhost:8444 |

## Writing Tests

### Using Shared Fixtures

All apps can use the shared authentication fixtures:

```typescript
import { test, expect } from '@playwright/test';
import { Services, authenticateWithKeycloak } from '../shared-fixtures';

test.describe('My Test Suite', () => {
  test('should access application', async ({ page }) => {
    // Authenticate with any Crucible app
    await authenticateWithKeycloak(page, Services.Blueprint.UI);

    // Your test logic here
    await expect(page).toHaveURL(/.*localhost:4725.*/);
  });
});
```

### Creating App-Specific Fixtures

Each app can extend the shared fixtures with app-specific helpers:

```typescript
// app/fixtures.ts
import { test as base, Page } from '@playwright/test';
import { Services, authenticateWithKeycloak } from '../shared-fixtures';

export async function authenticateMyAppWithKeycloak(page: Page): Promise<void> {
  await authenticateWithKeycloak(page, Services.MyApp.UI);
}

export const test = base.extend({
  myAppAuthenticatedPage: async ({ page }, use) => {
    await authenticateMyAppWithKeycloak(page);
    await use(page);
  },
});

export { expect } from '@playwright/test';
export { Services };
```

### Using App-Specific Fixtures

```typescript
import { test, expect } from './fixtures';

test.describe('My App Tests', () => {
  test('should be authenticated', async ({ myAppAuthenticatedPage }) => {
    // Page is already authenticated
    await expect(myAppAuthenticatedPage).toHaveURL(/.*localhost:4XXX.*/);
  });
});
```

### Test Organization

Each application follows this structure:

```
app-name/
├── app-name-test-plan.md      # Test plan documentation
├── fixtures.ts                # App-specific fixtures (optional)
└── tests/                     # Test files organized by feature
    ├── authentication-and-authorization/
    ├── feature-1/
    ├── feature-2/
    └── seed.spec.ts           # Initial authentication test
```

## Authentication

All Crucible applications use Keycloak for authentication. The shared fixtures provide:

- **authenticateWithKeycloak(page, appUrl, username?, password?)** - Generic auth helper
- **Services** - Object containing all service URLs
- **waitForAspireServices(page, services?)** - Check Aspire service health
- **checkServiceHealth(page, url)** - Check if a service is accessible

**Default credentials:**
- Username: `admin`
- Password: `admin`

**Available in `shared-fixtures.ts`:**

```typescript
import { Services } from './shared-fixtures';

// Access URLs
Services.Blueprint.UI          // http://localhost:4725
Services.Blueprint.API         // http://localhost:4724
Services.Player.UI            // http://localhost:4301
Services.Keycloak             // https://localhost:8443
Services.AspireDashboard      // http://localhost:18888
// ... and more
```

## Configuration

### Playwright Config (`playwright.config.ts`)

- **testDir**: `./` - Scans all app folders
- **testMatch**: `**/tests/**/*.spec.ts` - Matches all test files
- **timeout**: 60 seconds per test
- **retries**: 2 on CI, 0 locally
- **workers**: 1 on CI for stability, unlimited locally
- **reporters**: HTML, list, and JSON
- **ignoreHTTPSErrors**: true (for self-signed Keycloak cert)
- **viewport**: 1920x1080
- **video**: Retained on failure
- **screenshot**: On failure only

## Best Practices

1. **Use Shared Fixtures** - Import from `shared-fixtures.ts` for common functionality
2. **Organize by Feature** - Group related tests in feature folders
3. **Follow Test Plans** - Each app has a test plan document to guide implementation
4. **Authenticate Once** - Use fixtures to handle authentication automatically
5. **Use Descriptive Names** - Test file names should match test plan structure
6. **Check Service Health** - Use `waitForAspireServices()` when needed
7. **Handle HTTPS Errors** - Keycloak uses self-signed certs, `ignoreHTTPSErrors` is enabled
8. **Keep Tests Independent** - Tests should not depend on each other
9. **Clean Up After Tests** - Use `test.afterEach()` to clean up test data
10. **Use Page Object Pattern** - For complex pages, create page objects

## Troubleshooting

### Services Not Running

Ensure Aspire is running:
```bash
cd /workspaces/crucible-development/Crucible.AppHost
dotnet run
```

Check service health at: http://localhost:18888

### Authentication Failures

- Verify Keycloak is running: https://localhost:8443 (ignore cert warning)
- Check default credentials: admin/admin
- Ensure `ignoreHTTPSErrors: true` in playwright.config.ts
- Clear browser cookies/storage if tests are failing inconsistently

### Tests Timing Out

- Increase timeouts in playwright.config.ts
- Check network connectivity to services
- Verify services are fully started and healthy
- Use `page.waitForLoadState('networkidle')` for slow-loading pages

### Port Conflicts

- Check `.env/` files in the AppHost for correct port configurations
- Verify no other processes are using the required ports:
  ```bash
  lsof -i :4725  # Check if Blueprint port is in use
  ```

### Browser Issues

```bash
# Reinstall browsers
npx playwright install --force

# Install system dependencies
npx playwright install-deps
```

### Test Flakiness

- Use explicit waits instead of fixed timeouts
- Check for race conditions
- Verify test isolation (tests should be independent)
- Run tests in headed mode to debug: `./run-tests.sh headed blueprint`

## CI/CD Integration

Key considerations for running tests in CI/CD:
- Use `workers: 1` on CI for stability
- Set `retries: 2` to handle flaky tests
- Upload test results and videos as artifacts
- Run tests after Aspire services are healthy
- Set appropriate timeouts for service startup
- Use `npx playwright install --with-deps` to install browsers and dependencies

## Adding a New Application

To add tests for a new Crucible application:

1. **Create app folder structure:**
   ```bash
   mkdir -p app-name/tests
   ```

2. **Add test plan:**
   ```bash
   # Create app-name/app-name-test-plan.md
   ```

3. **Create fixtures (if needed):**
   ```typescript
   // app-name/fixtures.ts
   import { test as base } from '@playwright/test';
   import { Services, authenticateWithKeycloak } from '../shared-fixtures';

   export async function authenticateAppNameWithKeycloak(page) {
     await authenticateWithKeycloak(page, Services.AppName.UI);
   }

   export const test = base.extend({
     appNameAuthenticatedPage: async ({ page }, use) => {
       await authenticateAppNameWithKeycloak(page);
       await use(page);
     },
   });
   ```

4. **Add service URLs to `shared-fixtures.ts`:**
   ```typescript
   AppName: {
     UI: 'http://localhost:XXXX',
     API: 'http://localhost:XXXX',
   },
   ```

5. **Generate tests following the test plan**

6. **Update this README** with the new app in the status table

## Benefits of This Structure

1. **Scalability** - Easy to add new applications
2. **Isolation** - Each app's tests are independent
3. **Reusability** - Shared fixtures reduce duplication
4. **Clarity** - Clear organization by application and feature
5. **Flexibility** - Run tests per app or across all apps
6. **Maintainability** - Easy to find and update tests
7. **Consistency** - Uniform structure across all apps

## Resources

- [Playwright Documentation](https://playwright.dev/)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Test Plans](./*/test-plan.md) - Detailed test scenarios for each app
- [Aspire Dashboard](http://localhost:18888) - Monitor service health
- [Keycloak Admin](https://localhost:8443) - Identity provider admin

## Contributing

When adding tests:

1. Follow the test plan for your application
2. Use shared fixtures where possible
3. Create app-specific fixtures only when needed
4. Organize tests by feature/functionality
5. Ensure tests are self-contained and can run independently
6. Update test plans and this README
7. Add meaningful test descriptions and comments
8. Follow the existing code style and patterns

## Support

For issues or questions:
- Check test plan documentation in each app folder
- Review existing tests for examples
- Consult [Playwright documentation](https://playwright.dev/) for framework features
- Check the [troubleshooting section](#troubleshooting) above
