#!/bin/bash

# Blueprint Playwright Test Setup Script
# This script sets up the Playwright test environment

set -e

echo "=========================================="
echo "Blueprint Playwright Test Setup"
echo "=========================================="
echo ""

# Check if we're in the correct directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Please run this script from the tests directory."
    exit 1
fi

# Check Node.js installation
echo "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed. Please install Node.js v18 or higher."
    exit 1
fi

NODE_VERSION=$(node -v)
echo "✓ Node.js ${NODE_VERSION} found"
echo ""

# Check npm installation
echo "Checking npm installation..."
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install npm."
    exit 1
fi

NPM_VERSION=$(npm -v)
echo "✓ npm ${NPM_VERSION} found"
echo ""

# Install dependencies
echo "Installing npm dependencies..."
npm install
echo "✓ Dependencies installed"
echo ""

# Install Playwright browsers
echo "Installing Playwright browsers..."
npx playwright install chromium
echo "✓ Chromium browser installed"
echo ""

# Optional: Install all browsers
read -p "Do you want to install all browsers (Firefox, WebKit)? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    npx playwright install
    echo "✓ All browsers installed"
else
    echo "Skipping additional browsers (only Chromium installed)"
fi
echo ""

# Check if Aspire is running
echo "Checking Aspire services..."
if curl -s http://localhost:18888 > /dev/null 2>&1; then
    echo "✓ Aspire dashboard is accessible at http://localhost:18888"
else
    echo "⚠ Warning: Aspire dashboard is not accessible at http://localhost:18888"
    echo "  Please start Aspire services before running tests:"
    echo "  cd ../Crucible.AppHost && dotnet run"
fi
echo ""

# Check if Blueprint is accessible
echo "Checking Blueprint service..."
if curl -s http://localhost:4725 > /dev/null 2>&1; then
    echo "✓ Blueprint UI is accessible at http://localhost:4725"
else
    echo "⚠ Warning: Blueprint UI is not accessible at http://localhost:4725"
    echo "  Make sure Aspire services are running."
fi
echo ""

# Check if Keycloak is accessible
echo "Checking Keycloak service..."
if curl -k -s https://localhost:8443 > /dev/null 2>&1; then
    echo "✓ Keycloak is accessible at https://localhost:8443"
else
    echo "⚠ Warning: Keycloak is not accessible at https://localhost:8443"
    echo "  Make sure Aspire services are running."
fi
echo ""

# Setup complete
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start Aspire services (if not already running):"
echo "   cd ../Crucible.AppHost && dotnet run"
echo ""
echo "2. Run tests:"
echo "   npm test                  # Run all tests"
echo "   npm run test:ui           # Run with UI"
echo "   npm run test:headed       # Run in headed mode"
echo "   npm run test:debug        # Debug mode"
echo ""
echo "3. View test results:"
echo "   npm run test:report       # Open HTML report"
echo ""
echo "Documentation:"
echo "- README.md                  # Full documentation"
echo "- TEST_GENERATION_SUMMARY.md # Test coverage summary"
echo "- specs/blueprint-test-plan.md # Complete test plan"
echo ""
echo "Happy testing! 🎭"
