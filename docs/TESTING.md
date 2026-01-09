# Terraform Testing Framework

This document explains the Terraform testing framework for this project, including how to run tests locally, write new tests, and integrate tests into CI/CD pipelines.

All examples are based on the ECS-based solution included at `infra-ecs/`. However, the testing principles and practices explained at this document apply the EKS-based approach at `infra-eks/` as well.

## Overview

This project uses Terraform's native testing framework (available in Terraform 1.6+) to validate infrastructure as code. The testing strategy includes:

- **Unit Tests**: Test individual modules in isolation to verify resource configuration
- **Validation Tests**: Verify that variable validation rules work as expected

## Test Structure (ECS Example)

```
infra-ecs/
├── tests/
│   └── unit/
│       ├── alb.tftest.hcl              # ALB module tests (6 test runs)
│       ├── ecs_cluster.tftest.hcl      # ECS Cluster module tests (7 test runs)
│       ├── ecs_service.tftest.hcl      # ECS Service module tests (7 test runs)
│       ├── ecr.tftest.hcl              # ECR module tests (8 test runs)
│       └── ssl.tftest.hcl              # SSL module tests (6 test runs)
└── modules/
    ├── alb/
    ├── ecs_cluster/
    ├── ecs_service/
    ├── ecr/
    └── ssl/
```

## Prerequisites

- **Terraform >= 1.6.0** (tests use native testing framework)
- Basic understanding of Terraform configuration

Check your Terraform version:
```bash
terraform version
```

## Running Tests Locally

### Run All Tests (Recommended)

Use the centralized test script - the same one used in CI/CD:

```bash
cd infra-ecs
./run-tests.sh
```

This script:
- ✅ Validates all module syntax
- ✅ Runs all unit tests
- ✅ Same behavior as CI/CD and pre-commit hooks

### Alternative: Direct Terraform Test Commands

You can also run specific tests directly using Terraform:

```bash
cd infra-ecs
terraform init
# Run only the ALB basic configuration test
terraform test -filter=tests/unit/alb.tftest.hcl
```

**Note**: Direct Terraform test commands require proper module initialization and path configuration. The `run-tests.sh` script handles this automatically.

### Verbose Output

For detailed output including all assertions:
```bash
terraform test -verbose
```

## Understanding Test Files

### Test File Structure

Each `.tftest.hcl` file contains one or more test runs using **in-place testing pattern**:

```hcl
# Test suite description at the top
# Explains what this file tests

# Mock AWS provider for testing (required for in-place tests)
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "test_name" {
  command = plan

  variables {
    # Input variables for this test
    var_name = "value"
  }

  # Override data sources if needed (e.g., for AMI lookups)
  override_data {
    target = data.aws_ssm_parameter.example
    values = {
      value = "mock-value"
    }
  }

  assert {
    condition     = resource.attribute == expected_value
    error_message = "Descriptive error message"
  }

  # Multiple assert blocks can be used
  assert {
    condition     = another_condition
    error_message = "Another error message"
  }
}
```

### Test Modes

**Plan Mode** (`command = plan`):
- Used for unit tests
- Validates configuration without creating resources
- Fast and cost-free
- Verifies resource attributes, naming, and configuration

**Apply Mode** (`command = apply`):
- Creates real resources in AWS
- Slower and incurs AWS costs
- Tests real resource creation and interactions
- **Not used in this project** to avoid AWS costs during testing

## Writing New Tests

### Step 1: Crate Unit Test File

`tests/unit/new_module.tftest.hcl`

### Step 2: Write Test Runs

Use this template for **in-place testing**:

```hcl
# Test suite for My Module
# Brief description of what this module does

# Mock AWS provider (required for in-place tests)
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "module_basic_configuration" {
  command = plan

  variables {
    required_var = "test-value"
    optional_var = 123
  }

  # Override data sources if the module uses them
  # override_data {
  #   target = data.aws_ssm_parameter.example
  #   values = {
  #     value = "mock-ami-12345678"
  #   }
  # }

  # Test critical resource attributes
  assert {
    condition     = resource.name == "expected-name"
    error_message = "Resource name should follow naming convention"
  }

  # Test security settings
  assert {
    condition     = resource.security_setting == true
    error_message = "Security setting should be enabled"
  }
}

# Add more test runs for different scenarios
run "module_production_configuration" {
  command = plan

  variables {
    environment = "prod"
    # ... other variables
  }

  # Test production-specific settings
}

run "module_validation" {
  command = plan

  variables {
    # Test with edge case values
  }

  # Test variable validation rules
}
```

### Step 3: Add Test Run to Script

```bash
run_module_tests "new_module" "tests/unit/new_module.tftest.hcl" || ANY_FAILED=true
```

### Step 4: Run Tests Locally

```bash
cd infra-ecs
./run-tests.sh
```

## Best Practices

### Test Naming

- Use descriptive test run names: `alb_listeners_configured` not `test1`
- Prefix with module name for clarity: `ecs_service_deployment_configuration`
- Use snake_case for test run names

### Assertion Writing

```hcl
# Good: Specific condition with clear error message
assert {
  condition     = aws_alb.alb.name == "dev-test-project-alb"
  error_message = "ALB name should match environment and project name pattern"
}

# Bad: Vague condition and error message
assert {
  condition     = length(aws_alb.alb.name) > 0
  error_message = "Name is wrong"
}
```

### Test Coverage

For each module, test:
1. **Resource Creation**: Verify the resource is created with correct name
2. **Configuration**: Test critical attributes match input variables
3. **Security**: Verify security settings are correctly configured
4. **Defaults**: Test that default values work as expected
5. **Validation**: Test that variable validation rules work
6. **Tagging**: Verify resources have correct tags

### Use Realistic Test Data

```hcl
# Good: Realistic ARN format
ecs_cluster_arn = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"

# Bad: Fake data that doesn't match AWS format
ecs_cluster_arn = "test-cluster"
```

### Test One Thing Per Assert

```hcl
# Good: Separate assertions for each attribute
assert {
  condition     = aws_alb.alb.name == "dev-test-alb"
  error_message = "ALB name should be correct"
}

assert {
  condition     = aws_alb.alb.internal == false
  error_message = "ALB should be internet-facing"
}

# Bad: Testing multiple things in one assertion
assert {
  condition     = aws_alb.alb.name == "dev-test-alb" && aws_alb.alb.internal == false
  error_message = "ALB configuration is wrong"  # Which part failed?
}
```

## Testing Patterns

### Testing String Attributes

```hcl
assert {
  condition     = aws_ecs_cluster.ecs_cluster.name == "dev-test-ecs-cluster"
  error_message = "Cluster name should match pattern"
}
```

### Testing Boolean Attributes

```hcl
assert {
  condition     = aws_ecr_repository.repo.image_scanning_configuration[0].scan_on_push == true
  error_message = "Image scanning should be enabled"
}
```

### Testing Numeric Attributes

```hcl
assert {
  condition     = tonumber(aws_ecs_task_definition.task.cpu) == 512
  error_message = "CPU should match configured value"
}
```

### Testing Lists

```hcl
assert {
  condition     = length(aws_security_group.sg.ingress) > 0
  error_message = "Security group should have ingress rules"
}
```

### Testing with Regex

```hcl
assert {
  condition     = can(regex("ecs-tasks\\.amazonaws\\.com", aws_iam_role.role.assume_role_policy))
  error_message = "Role should trust ECS tasks service"
}
```

### Testing JSON Content

```hcl
assert {
  condition     = can(regex("\"containerPort\":\\s*3000", aws_ecs_task_definition.task.container_definitions))
  error_message = "Container should expose port 3000"
}
```

### Testing Map Values

```hcl
assert {
  condition     = aws_security_group.sg.tags["Environment"] == "dev"
  error_message = "Resource should have Environment tag"
}
```

## CI/CD Integration

### GitHub Actions

The project includes automated testing in the CI/CD pipeline. Tests are run:
- ✅ On every push to main branch
- ✅ Before deploying any infrastructure
- ✅ As the first job in the deployment pipeline

**Implementation Location:** [.github/workflows/ecs_deploy_aws_infra.yaml](../.github/workflows/ecs_deploy_aws_infra.yaml)

The `test-ecs-terraform-modules` job runs first and blocks all deployments if tests fail. The job:

1. **Validates module syntax** - Runs `terraform validate` on all modules
2. **Runs unit tests** - Tests each module (ALB, ECS Cluster, ECS Service, ECR)
3. **Reports results** - Provides clear pass/fail status with error messages
4. **Blocks deployment** - All other jobs depend on tests passing

### Pre-Commit and Pre-Push Hook Integration

Tests run automatically at two stages to ensure code quality:

**Configuration Location:** [.pre-commit-config.yaml](../.pre-commit-config.yaml)

#### Pre-Commit Hooks

Standard pre-commit hooks run when committing changes:
- **terraform_fmt** - Format Terraform files
- **terraform_validate** - Validate Terraform syntax
- **terraform_tflint** - Lint Terraform code
- **terraform_trivy** - Security vulnerability scanning
- **terraform_docs** - Generate module documentation
- **detect-secrets** - Prevent commits including secrets

These hooks run on every commit to enforce code quality and security standards before code is committed.

#### Pre-Push Hooks (Terraform Tests)

Terraform module tests run automatically when pushing changes to the remote repository:

**Hook ID:** `terraform-ecs-tests`
- **Triggers on**: Any push where changes were made to `*.tf`, `*.tfvars`, or `*.tftest.hcl` files within `infra-ecs/` directory tree
- **Runs**: `./pre-push.sh infra-ecs` which executes `infra-ecs/run-tests.sh`
- **Blocks push**: If any ECS module tests fail
- **Purpose**: Validates all ECS Terraform modules before code reaches the remote repository

**Hook ID:** `terraform-eks-tests`
- **Triggers on**: Any push where changes were made to `*.tf`, `*.tfvars`, or `*.tftest.hcl` files within `infra-eks/` directory tree
- **Runs**: `./pre-push.sh infra-eks` which executes `infra-eks/run-tests.sh`
- **Blocks push**: If any EKS module tests fail
- **Purpose**: Validates all EKS Terraform modules before code reaches the remote repository

**Why Pre-Push Instead of Pre-Commit?**
- Terraform tests can take several minutes to complete
- Running on push (rather than commit) provides faster commit cycles
- Tests only run when relevant Terraform files have changed
- Still catches issues before code reaches CI/CD pipeline

To skip the test hooks (⚠️ not recommended):
```bash
git push --no-verify
```

To skip pre-commit hooks (⚠️ not recommended):
```bash
git commit --no-verify
```

### Viewing Test Results

When the workflow runs, you can view test results in the GitHub Actions UI:

1. Go to **Actions** tab in your repository
2. Click on the workflow run
3. Click on the **Test Terraform Modules** job
4. Expand the test steps to see:
   - ✓ Module validation results
   - ✓ Individual test run results
   - ✗ Failure details if tests fail

### Test Failure Behavior

If tests fail:
- ❌ The `test-ecs-terraform-modules` job fails
- 🛑 All deployment jobs are skipped (they depend on tests)
- 🔴 Workflow shows as failed in GitHub UI
- 💬 Error messages indicate which module/test failed

## Troubleshooting

### Test Fails with "Module not found"

**Problem**: Test can't find the module source.

**Solution**: Check the relative path in the `module` block:
```hcl
module {
  source = "../../modules/my_module"  # Path from test file to module
}
```

### Test Fails with "Required variable not set"

**Problem**: Missing required variable in test.

**Solution**: Add all required variables to the `variables` block:
```hcl
variables {
  required_var1 = "value1"
  required_var2 = "value2"
}
```

### Assert Fails with Unclear Error

**Problem**: Hard to understand why test failed.

**Solution**: Use `-verbose` flag for detailed output:
```bash
terraform test -filter=tests/unit/my_module.tftest.hcl -verbose
```

### Test Passes Locally but Fails in CI

**Problem**: Different Terraform versions or missing initialization.

**Solution**: Ensure CI uses same Terraform version:
```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.11.2  # Match your local version
```

#### Tests Fail Locally But Pass in CI

- Check Terraform version: `terraform version` (requires 1.7.0+)
- Ensure modules are up to date: `cd infra-ecs && git pull`
- Clean temporary files: `rm -rf tests/.tmp`

### Testing Validation Rules

**Problem**: Want to verify that invalid input is rejected.

**Solution**: Variable validation happens at plan time. Currently, Terraform tests don't have built-in support for testing validation failures. Document validation rules separately (see [VARIABLE_VALIDATION.md](VARIABLE_VALIDATION.md)).

### Regex Not Matching JSON Content

**Problem**: Regex assertion fails on JSON content.

**Solution**: Escape special characters and use flexible whitespace matching:
```hcl
# Use \s* for flexible whitespace
can(regex("\"key\"\\s*:\\s*\"value\"", json_content))

# Escape dots in domain names
can(regex("ecs-tasks\\.amazonaws\\.com", content))
```

#### Permission Denied Error

```bash
chmod +x run-tests.sh
```

## Test Maintenance

### When to Update Tests

Update tests when:
- Adding new modules (create new test file)
- Changing module behavior (update existing tests)
- Adding new variables (add test coverage)
- Fixing bugs (add regression test)
- Updating security requirements (add/update security assertions)

### Keeping Tests in Sync

1. When you modify a module, run its tests:
   ```bash
   terraform test -filter=tests/unit/module_name.tftest.hcl
   ```

2. If tests fail after valid changes, update the tests to match new behavior

3. Add new tests for new functionality

4. Remove tests for removed features

### Test Review Checklist

- [ ] All test runs have descriptive names
- [ ] Each assert has a clear error message
- [ ] Tests cover critical functionality
- [ ] Tests use realistic data
- [ ] Tests verify security settings
- [ ] Tests check resource naming conventions
- [ ] Tests validate required tags

## Reference

### Terraform Test Documentation

- [Terraform Test Command](https://developer.hashicorp.com/terraform/cli/commands/test)
- [Writing Tests](https://developer.hashicorp.com/terraform/language/tests)
- [Test Syntax](https://developer.hashicorp.com/terraform/language/tests/syntax)

### Related Documentation

- [Variable Validation Rules](VARIABLE_VALIDATION.md) - Details on input validation
- [Security Documentation](SECURITY.md) - Security requirements tested
- [ADRs](adr/) - Architecture decisions that influence tests

## Summary

- **Unit tests** verify individual module configuration and behavior
- **Plan mode** tests avoid AWS costs while validating configuration
- **Clear assertions** with descriptive error messages aid debugging
- **Comprehensive coverage** includes security, naming, tagging, and functionality

Run `./run-tests.sh` before committing changes to catch issues early!

## Maintenance

**Last Updated:** 2026-01-07

Review and update this documentation when:
- Adding new test files or test patterns
- Changing test infrastructure or CI/CD integration
- Updating Terraform version (check for new testing features)
- Receiving feedback about unclear testing procedures
