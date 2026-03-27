#!/bin/bash

# Crucible Playwright Test Runner
# Convenient script for running tests for different Crucible applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if services are running
check_services() {
    echo -e "${BLUE}Checking required services...${NC}"
    
    local all_ok=true
    
    if curl -s http://localhost:4725 > /dev/null 2>&1; then
        print_success "Blueprint UI (http://localhost:4725)"
    else
        print_error "Blueprint UI not accessible"
        all_ok=false
    fi
    
    if curl -k -s https://localhost:8443 > /dev/null 2>&1; then
        print_success "Keycloak (https://localhost:8443)"
    else
        print_error "Keycloak not accessible"
        all_ok=false
    fi
    
    if curl -s http://localhost:18888 > /dev/null 2>&1; then
        print_success "Aspire Dashboard (http://localhost:18888)"
    else
        print_warning "Aspire Dashboard not accessible (optional)"
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        print_error "Required services are not running!"
        echo ""
        echo "Please start Aspire services:"
        echo "  cd /workspaces/crucible-development/Crucible.AppHost && dotnet run"
        echo ""
        exit 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
Crucible Playwright Test Runner

Usage: $0 [app|command] [options]

Applications:
  keycloak               Run Keycloak (Identity Provider) tests
  blueprint              Run Blueprint tests
  player                 Run Player tests
  cite                   Run CITE tests
  gameboard              Run Gameboard tests
  topomojo               Run TopoMojo tests
  steamfitter            Run Steamfitter tests
  moodle                 Run Moodle tests
  alloy                  Run Alloy tests
  caster                 Run Caster tests
  gallery                Run Gallery tests

Commands:
  all                    Run all tests for all apps
  quick                  Run quick smoke tests
  ui [app]               Run tests in UI mode (optionally for specific app)
  headed [app]           Run tests in headed mode (optionally for specific app)
  debug [app]            Run tests in debug mode (optionally for specific app)
  report                 Show test report
  help                   Show this help message

Options:
  --no-check            Skip service health checks
  --filter <pattern>    Filter tests by pattern
  --app <app>           Run tests for specific app

Examples:
  $0 all                # Run all tests for all apps
  $0 blueprint          # Run all Blueprint tests
  $0 quick --app blueprint  # Run Blueprint smoke tests
  $0 ui blueprint       # Run Blueprint tests in UI mode
  $0 --filter login --app player  # Run Player tests matching 'login'

EOF
}

# Parse arguments
COMMAND=${1:-help}
APP=""
NO_CHECK=false
FILTER=""

shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-check)
            NO_CHECK=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --app)
            APP="$2"
            shift 2
            ;;
        keycloak|blueprint|player|cite|gameboard|topomojo|steamfitter|moodle|alloy|caster|gallery)
            APP="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check services unless --no-check is specified
if [ "$NO_CHECK" = false ] && [ "$COMMAND" != "help" ] && [ "$COMMAND" != "report" ]; then
    check_services
fi

# Execute command
case $COMMAND in
    all)
        print_header "Running All Tests"
        if [ -n "$APP" ]; then
            print_warning "Running tests for app: $APP"
            if [ -n "$FILTER" ]; then
                npx playwright test "$APP/" --grep "$FILTER"
            else
                npx playwright test "$APP/"
            fi
        else
            if [ -n "$FILTER" ]; then
                npx playwright test --grep "$FILTER"
            else
                npx playwright test
            fi
        fi
        ;;

    keycloak|blueprint|player|cite|gameboard|topomojo|steamfitter|moodle|alloy|caster|gallery)
        print_header "Running $COMMAND Tests"
        if [ -n "$FILTER" ]; then
            npx playwright test "$COMMAND/" --grep "$FILTER"
        else
            npx playwright test "$COMMAND/"
        fi
        ;;

    quick)
        print_header "Running Quick Smoke Tests"
        if [ -n "$APP" ]; then
            print_warning "Running smoke tests for: $APP"
            npx playwright test "$APP/tests/" --grep "login|home"
        else
            print_warning "Running smoke tests for Blueprint (default)"
            npx playwright test blueprint/tests/authentication-and-authorization/user-login-flow.spec.ts
            npx playwright test blueprint/tests/home-page-and-navigation/home-page-initial-load.spec.ts
        fi
        print_success "Smoke tests complete!"
        ;;

    ui)
        print_header "Running Tests in UI Mode"
        TEST_PATH=""
        if [ -n "$APP" ]; then
            TEST_PATH="$APP/"
            print_warning "Running UI tests for: $APP"
        fi
        if [ -n "$FILTER" ]; then
            npx playwright test "$TEST_PATH" --ui --grep "$FILTER"
        else
            npx playwright test "$TEST_PATH" --ui
        fi
        ;;

    headed)
        print_header "Running Tests in Headed Mode"
        TEST_PATH=""
        if [ -n "$APP" ]; then
            TEST_PATH="$APP/"
            print_warning "Running headed tests for: $APP"
        fi
        if [ -n "$FILTER" ]; then
            npx playwright test "$TEST_PATH" --headed --grep "$FILTER"
        else
            npx playwright test "$TEST_PATH" --headed
        fi
        ;;

    debug)
        print_header "Running Tests in Debug Mode"
        TEST_PATH=""
        if [ -n "$APP" ]; then
            TEST_PATH="$APP/"
            print_warning "Running debug tests for: $APP"
        fi
        if [ -n "$FILTER" ]; then
            npx playwright test "$TEST_PATH" --debug --grep "$FILTER"
        else
            npx playwright test "$TEST_PATH" --debug
        fi
        ;;

    report)
        print_header "Opening Test Report"
        npx playwright show-report
        ;;

    help|--help|-h)
        show_usage
        ;;

    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
print_success "Done!"
