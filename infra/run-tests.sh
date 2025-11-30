#!/bin/bash

# Terraform Module Test Runner
# This script runs all Terraform module tests
# Can be used locally, in CI/CD, or as a pre-commit hook

set -e

# Detect if running in GitHub Actions
IS_CI=${CI:-false}
IS_GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}

# Colors for output (disabled in CI)
if [ "$IS_CI" = "true" ] || [ "$IS_GITHUB_ACTIONS" = "true" ]; then
    GREEN=''
    RED=''
    YELLOW=''
    NC=''
else
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

# GitHub Actions logging functions
gh_error() {
    if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
        echo "::error::$1"
    fi
    echo -e "${RED}✗ $1${NC}" >&2
}

gh_notice() {
    if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
        echo "::notice::$1"
    fi
    echo -e "${GREEN}✓ $1${NC}"
}

gh_warning() {
    if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
        echo "::warning::$1"
    fi
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "================================"
echo "Terraform Module Test Suite"
echo "================================"
echo ""

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_MODULES=()

# Function to run tests for a single module
run_module_tests() {
    local module_name=$1
    local test_file=$2

    echo "Testing $module_name module..."

    # Check if module exists
    if [ ! -d "modules/$module_name" ]; then
        gh_warning "Module $module_name not found, skipping"
        return 0
    fi

    # Check if test file exists
    if [ ! -f "$test_file" ]; then
        gh_warning "Test file $test_file not found, skipping"
        return 0
    fi

    # Create temporary test directory
    local test_dir="tests/.tmp/$module_name"
    mkdir -p "$test_dir"

    # Copy module files
    cp -r "modules/$module_name/"* "$test_dir/" 2>/dev/null || {
        gh_error "Failed to copy module files for $module_name"
        return 1
    }

    # Copy test file to tests subdirectory
    mkdir -p "$test_dir/tests"
    cp "$test_file" "$test_dir/tests/"

    # Update module source paths in test file (compatible with both macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's|source = "../../modules/'$module_name'"|source = "./.."|g' "$test_dir/tests/$(basename $test_file)"
    else
        # Linux
        sed -i 's|source = "../../modules/'$module_name'"|source = "./.."|g' "$test_dir/tests/$(basename $test_file)"
    fi

    # Initialize and run tests
    cd "$test_dir"

    # Initialize Terraform
    if ! terraform init > /dev/null 2>&1; then
        cd - > /dev/null
        gh_error "Terraform init failed for $module_name module"
        FAILED_MODULES+=("$module_name")
        return 1
    fi

    # Run tests
    local test_output_file="test-output.txt"
    if terraform test -no-color 2>&1 | tee "$test_output_file"; then
        # Count passed tests (look for lines ending with "pass")
        local passed=$(grep -c "pass$" "$test_output_file" 2>/dev/null || echo "0")

        if [ "$passed" -eq 0 ]; then
            # If no passes found, count Success! lines
            passed=$(grep -c "Success!" "$test_output_file" 2>/dev/null || echo "1")
        fi

        PASSED_TESTS=$((PASSED_TESTS + passed))
        TOTAL_TESTS=$((TOTAL_TESTS + passed))

        cd - > /dev/null
        gh_notice "$module_name tests passed ($passed test runs)"
        return 0
    else
        # Count failed tests
        local failed=$(grep -c "fail$" "$test_output_file" 2>/dev/null || echo "1")
        FAILED_TESTS=$((FAILED_TESTS + failed))
        TOTAL_TESTS=$((TOTAL_TESTS + failed))
        FAILED_MODULES+=("$module_name")

        cd - > /dev/null
        gh_error "Tests failed for $module_name module"

        # Show error details in GitHub Actions
        if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
            echo "::group::$module_name test failure details"
            cat "$test_dir/$test_output_file" 2>/dev/null || echo "No output available"
            echo "::endgroup::"
        fi

        return 1
    fi
}

# Function to validate module syntax
validate_module() {
    local module_path=$1
    local module_name=$(basename "$module_path")

    echo "Validating $module_name module syntax..."

    cd "$module_path"

    if ! terraform init -backend=false > /dev/null 2>&1; then
        cd - > /dev/null
        gh_error "Failed to initialize $module_name for validation"
        return 1
    fi

    if terraform validate > /dev/null 2>&1; then
        cd - > /dev/null
        gh_notice "$module_name syntax is valid"
        return 0
    else
        cd - > /dev/null
        gh_error "$module_name has syntax errors"
        return 1
    fi
}

# Clean up any previous test runs
rm -rf tests/.tmp

# Step 1: Validate all module syntax
echo "Step 1: Validating Terraform module syntax"
echo "-------------------------------------------"
echo ""

VALIDATION_FAILED=false
for module_dir in modules/*/; do
    if [ -d "$module_dir" ]; then
        validate_module "$module_dir" || VALIDATION_FAILED=true
    fi
done

echo ""

if [ "$VALIDATION_FAILED" = true ]; then
    gh_error "Module validation failed - fix syntax errors before running tests"
    exit 1
fi

# Step 2: Run unit tests
echo "Step 2: Running unit tests"
echo "--------------------------"
echo ""

# Track if any tests failed
ANY_FAILED=false

run_module_tests "alb" "tests/unit/alb.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecs_cluster" "tests/unit/ecs_cluster.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecs_service" "tests/unit/ecs_service.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecr" "tests/unit/ecr.tftest.hcl" || ANY_FAILED=true

echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo ""
    echo "Failed modules:"
    for module in "${FAILED_MODULES[@]}"; do
        echo -e "  ${RED}✗${NC} $module"
    done
fi

echo ""

# Clean up
rm -rf tests/.tmp

if [ "$FAILED_TESTS" -gt 0 ] || [ "$ANY_FAILED" = true ]; then
    gh_error "Some tests failed!"
    if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
        echo "::error::$FAILED_TESTS test(s) failed across ${#FAILED_MODULES[@]} module(s)"
    fi
    exit 1
else
    gh_notice "All tests passed!"
    if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
        echo "::notice::All $PASSED_TESTS tests passed successfully"
    fi
    echo ""
    echo "Test run complete."
    exit 0
fi
