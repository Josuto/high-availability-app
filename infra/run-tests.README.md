# Terraform Test Runner

**Script:** `run-tests.sh`

## Purpose

Centralized script for running all Terraform module tests. Used consistently across:
- ✅ Local development
- ✅ Pre-commit hooks
- ✅ CI/CD pipeline (GitHub Actions)

## Usage

### Run All Tests

```bash
cd infra
./run-tests.sh
```

### What It Does

1. **Validates Module Syntax**
   - Runs `terraform validate` on all modules
   - Catches syntax errors before running tests

2. **Runs Unit Tests**
   - Tests ALB module (6 test runs)
   - Tests ECS Cluster module (7 test runs)
   - Tests ECS Service module (7 test runs)
   - Tests ECR module (8 test runs)

3. **Reports Results**
   - Colored output for local development
   - GitHub Actions annotations for CI/CD
   - Clear pass/fail status

4. **Exit Codes**
   - `0` - All tests passed
   - `1` - One or more tests failed

## Features

### Cross-Platform Support
- Works on macOS and Linux
- Handles `sed` differences automatically

### CI/CD Integration
- Detects GitHub Actions environment
- Provides `::error::` and `::notice::` annotations
- Groups failure details for easy debugging

### Smart Cleanup
- Creates temporary directories for isolated testing
- Cleans up after completion
- Handles errors gracefully

## Output Example

```
================================
Terraform Module Test Suite
================================

Step 1: Validating Terraform module syntax
-------------------------------------------

Validating alb module syntax...
✓ alb syntax is valid
Validating ecs_cluster module syntax...
✓ ecs_cluster syntax is valid
Validating ecs_service module syntax...
✓ ecs_service syntax is valid
Validating ecr module syntax...
✓ ecr syntax is valid

Step 2: Running unit tests
--------------------------

Testing alb module...
✓ alb tests passed (7 test runs)
Testing ecs_cluster module...
✓ ecs_cluster tests passed (8 test runs)
Testing ecs_service module...
✓ ecs_service tests passed (8 test runs)
Testing ecr module...
✓ ecr tests passed (9 test runs)

================================
Test Summary
================================
Total tests: 32
Passed: 32
Failed: 0

✓ All tests passed!

Test run complete.
```

## Integration Points

### 1. CI/CD Pipeline

**File:** `.github/workflows/deploy_aws_infra.yaml`

```yaml
- name: Run Terraform module tests
  run: |
    export AWS_ACCESS_KEY_ID="mock-access-key"
    export AWS_SECRET_ACCESS_KEY="mock-secret-key"  # pragma: allowlist secret
    export AWS_DEFAULT_REGION="eu-west-1"
    cd infra
    chmod +x run-tests.sh
    ./run-tests.sh
```

**Note:** The explicit `export` statements ensure AWS credentials are available for module validation, particularly for modules with AWS data sources (like ecs_cluster).

### 2. Pre-Commit Hook

**File:** `.pre-commit-config.yaml`

```yaml
- repo: local
  hooks:
    - id: terraform-tests
      name: Terraform Module Tests
      entry: bash -c 'cd infra && ./run-tests.sh'
      files: ^infra/(modules/|tests/).*\.(tf|tftest\.hcl)$
```

### 3. Manual Execution

```bash
cd infra
./run-tests.sh
```

## Maintenance

### Adding a New Module Test

1. Create test file: `tests/unit/new_module.tftest.hcl`
2. Add test run to script:
   ```bash
   run_module_tests "new_module" "tests/unit/new_module.tftest.hcl" || ANY_FAILED=true
   ```
3. Test locally: `./run-tests.sh`

### Skipping Tests (Not Recommended)

**Pre-commit:**
```bash
git commit --no-verify
```

**Note:** CI/CD tests cannot be skipped and will still block deployments.

## Troubleshooting

### Tests Fail Locally But Pass in CI

- Check Terraform version: `terraform version`
- Ensure modules are up to date: `cd infra && git pull`
- Clean temporary files: `rm -rf tests/.tmp`

### Permission Denied Error

```bash
chmod +x run-tests.sh
```

### ECS Cluster Module Fails to Initialize

If you see "Failed to initialize ecs_cluster for validation", you need mock AWS credentials:

```bash
# The ecs_cluster module has data sources that require AWS credentials
export AWS_ACCESS_KEY_ID="mock-access-key"
export AWS_SECRET_ACCESS_KEY="mock-secret-key" # pragma: allowlist secret
export AWS_DEFAULT_REGION="eu-west-1"
./run-tests.sh
```

**Why this is needed:**
- The ecs_cluster module queries AWS SSM Parameter Store for ECS-optimized AMI IDs
- Terraform requires credentials to initialize the AWS provider, even for validation
- Mock credentials satisfy this requirement without making actual AWS API calls
- CI/CD pipeline automatically provides these credentials

### Tests Take Too Long

The script runs all tests sequentially. This is intentional to:
- Ensure clean state between module tests
- Avoid resource conflicts
- Provide clear, isolated failure messages

Typical run time: 1-3 minutes for all modules.

## Technical Details

### How It Works

1. **Temporary Test Directories**
   - Each module test runs in `tests/.tmp/{module_name}/`
   - Module files copied to temporary location
   - Test files copied and source paths updated
   - Isolated Terraform initialization

2. **Path Transformations**
   - Test files reference: `source = "../../modules/{module}"`
   - Script transforms to: `source = "./.."`
   - Allows tests to find module in temporary directory

3. **Result Tracking**
   - Counts passed/failed tests
   - Tracks failed modules
   - Provides detailed summary

### Environment Variables

- `CI`: Set to `true` in CI environments
- `GITHUB_ACTIONS`: Set to `true` in GitHub Actions
- `OSTYPE`: Used to detect macOS vs Linux

## Benefits of This Approach

✅ **Consistency**: Same logic runs everywhere
✅ **Maintainability**: Update tests in one place
✅ **Reliability**: Isolated test execution prevents interference
✅ **Visibility**: Clear output for debugging
✅ **Automation**: Integrates with pre-commit and CI/CD

## Documentation

- **Testing Guide**: [docs/TESTING.md](../docs/TESTING.md)
- **Testing Summary**: [docs/TESTING_SUMMARY.md](../docs/TESTING_SUMMARY.md)
- **Variable Validation**: [docs/VARIABLE_VALIDATION.md](../docs/VARIABLE_VALIDATION.md)

## Version

**Last Updated:** 2025-12-01
**Terraform Version:** 1.7.0+ (required for `override_data` support in tests)
**Test Framework:** Terraform Native Testing (1.6+)
