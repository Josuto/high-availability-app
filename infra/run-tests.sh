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

# Function to run tests for a single module (in-place testing)
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

    # Create temporary test directory for this module
    local test_dir="tests/.tmp/$module_name"
    mkdir -p "$test_dir"

    # Copy module files to temp directory
    cp -r "modules/$module_name/"* "$test_dir/" 2>/dev/null || {
        gh_error "Failed to copy module files for $module_name"
        return 1
    }

    # Copy test file directly to the module directory (in-place testing)
    # For in-place testing, the test file must be in the same directory as the module files
    cp "$test_file" "$test_dir/$(basename $test_file)"

    # Change to test directory
    cd "$test_dir"

    # Initialize Terraform
    local init_output=$(terraform init 2>&1)
    local init_exit_code=$?

    if [ $init_exit_code -ne 0 ]; then
        cd - > /dev/null
        gh_error "Terraform init failed for $module_name module"

        if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
            echo "::group::$module_name init failure details"
            echo "$init_output"
            echo "::endgroup::"
        fi

        FAILED_MODULES+=("$module_name")
        return 1
    fi

    # Run tests
    local test_output=$(terraform test -no-color 2>&1)
    local test_exit_code=$?

    if [ $test_exit_code -eq 0 ]; then
        # Count passed tests (look for lines ending with "pass")
        local passed=$(echo "$test_output" | grep -c "pass$" 2>/dev/null)

        # Ensure passed is a valid integer (default to 0 if empty or invalid)
        if [ -z "$passed" ] || ! [[ "$passed" =~ ^[0-9]+$ ]]; then
            passed=0
        fi

        if [ "$passed" -eq 0 ]; then
            # If no passes found, count Success! lines
            passed=$(echo "$test_output" | grep -c "Success!" 2>/dev/null)
            if [ -z "$passed" ] || ! [[ "$passed" =~ ^[0-9]+$ ]]; then
                passed=1
            fi
        fi

        PASSED_TESTS=$((PASSED_TESTS + passed))
        TOTAL_TESTS=$((TOTAL_TESTS + passed))

        cd - > /dev/null
        gh_notice "$module_name tests passed ($passed test runs)"
        return 0
    else
        # Count failed tests
        local failed=$(echo "$test_output" | grep -c "fail$" 2>/dev/null)
        if [ -z "$failed" ] || ! [[ "$failed" =~ ^[0-9]+$ ]]; then
            failed=1
        fi

        FAILED_TESTS=$((FAILED_TESTS + failed))
        TOTAL_TESTS=$((TOTAL_TESTS + failed))
        FAILED_MODULES+=("$module_name")

        cd - > /dev/null
        gh_error "Tests failed for $module_name module"

        # Show error details in GitHub Actions
        if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
            echo "::group::$module_name test failure details"
            echo "$test_output"
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

    # Capture init output for debugging
    local init_output=$(terraform init -backend=false 2>&1)
    local init_exit_code=$?

    if [ $init_exit_code -ne 0 ]; then
        cd - > /dev/null
        gh_error "Failed to initialize $module_name for validation"

        # Show detailed error in GitHub Actions or when verbose
        if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
            echo "::group::$module_name initialization failure details"
            echo "$init_output"
            echo "::endgroup::"
        elif [ "${VERBOSE:-false}" = "true" ]; then
            echo "$init_output" >&2
        fi

        return 1
    fi

    local validate_output=$(terraform validate 2>&1)
    local validate_exit_code=$?

    if [ $validate_exit_code -eq 0 ]; then
        cd - > /dev/null
        gh_notice "$module_name syntax is valid"
        return 0
    else
        cd - > /dev/null
        gh_error "$module_name has syntax errors"

        # Show validation errors in GitHub Actions or when verbose
        if [ "$IS_GITHUB_ACTIONS" = "true" ]; then
            echo "::group::$module_name validation errors"
            echo "$validate_output"
            echo "::endgroup::"
        elif [ "${VERBOSE:-false}" = "true" ]; then
            echo "$validate_output" >&2
        fi

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
run_module_tests "ssl" "tests/unit/ssl.tftest.hcl" || ANY_FAILED=true

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
