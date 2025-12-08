#!/bin/bash

# Terraform Module Test Runner
# This script runs all Terraform module tests and shows terraform test output

set -e

echo "================================"
echo "Terraform Module Test Suite"
echo "================================"
echo ""

# Track test results
FAILED_MODULES=()

# Function to run tests for a single module
run_module_tests() {
    local module_name=$1
    local test_file=$2

    echo "Testing $module_name module..."
    echo "----------------------------------------"

    # Check if module exists
    if [ ! -d "modules/$module_name" ]; then
        echo "Module $module_name not found, skipping"
        echo ""
        return 0
    fi

    # Check if test file exists
    if [ ! -f "$test_file" ]; then
        echo "Test file $test_file not found, skipping"
        echo ""
        return 0
    fi

    # Create temporary test directory for this module
    local test_dir="tests/.tmp/$module_name"
    mkdir -p "$test_dir"

    # Copy module files to temp directory
    cp -r "modules/$module_name/"* "$test_dir/" 2>/dev/null || {
        echo "✗ Failed to copy module files for $module_name"
        echo ""
        return 1
    }

    # Copy test file
    cp "$test_file" "$test_dir/$(basename $test_file)"

    # Change to test directory
    cd "$test_dir"

    # Initialize Terraform (suppress output)
    terraform init > /dev/null 2>&1
    local init_exit_code=$?

    if [ $init_exit_code -ne 0 ]; then
        cd - > /dev/null
        echo "✗ Terraform init failed for $module_name module"
        echo ""
        FAILED_MODULES+=("$module_name")
        return 1
    fi

    # Run tests and show output directly
    terraform test -no-color
    local test_exit_code=$?

    cd - > /dev/null
    echo ""

    if [ $test_exit_code -ne 0 ]; then
        FAILED_MODULES+=("$module_name")
        return 1
    fi

    return 0
}

# Function to validate module syntax
validate_module() {
    local module_path=$1
    local module_name=$(basename "$module_path")

    echo "Validating $module_name module syntax..."

    cd "$module_path"

    # Initialize and validate (suppress init output)
    terraform init -backend=false > /dev/null 2>&1
    local init_exit_code=$?

    if [ $init_exit_code -ne 0 ]; then
        cd - > /dev/null
        echo "✗ Failed to initialize $module_name for validation"
        return 1
    fi

    terraform validate > /dev/null 2>&1
    local validate_exit_code=$?

    cd - > /dev/null

    if [ $validate_exit_code -eq 0 ]; then
        echo "✓ $module_name syntax is valid"
        return 0
    else
        echo "✗ $module_name has syntax errors"
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
    echo "✗ Module validation failed - fix syntax errors before running tests"
    exit 1
fi

# Step 2: Run unit tests
echo "Step 2: Running unit tests for all modules"
echo "-------------------------------------------"
echo ""

# Track if any tests failed (use set +e to continue on failures)
set +e
ANY_FAILED=false

run_module_tests "alb" "tests/unit/alb.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecs_cluster" "tests/unit/ecs_cluster.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecs_service" "tests/unit/ecs_service.tftest.hcl" || ANY_FAILED=true
run_module_tests "ecr" "tests/unit/ecr.tftest.hcl" || ANY_FAILED=true
run_module_tests "ssl" "tests/unit/ssl.tftest.hcl" || ANY_FAILED=true

# Re-enable exit on error
set -e

# Summary
echo "================================"
echo "Test Summary"
echo "================================"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo "Failed modules:"
    for module in "${FAILED_MODULES[@]}"; do
        echo "  ✗ $module"
    done
    echo ""
fi

# Clean up
rm -rf tests/.tmp

if [ "$ANY_FAILED" = true ]; then
    echo "✗ Some tests failed!"
    exit 1
else
    echo "✓ All tests passed!"
    echo ""
    echo "Test run complete."
    exit 0
fi
