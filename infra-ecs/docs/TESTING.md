# Terraform Testing Framework

This document explains the Terraform testing framework for this project, including how to run tests locally, write new tests, and integrate tests into CI/CD pipelines.

## Overview

This project uses Terraform's native testing framework (available in Terraform 1.6+) to validate infrastructure as code. The testing strategy includes:

- **Unit Tests**: Test individual modules in isolation to verify resource configuration
- **Validation Tests**: Verify that variable validation rules work as expected

## Test Structure

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

**Total: 34 test runs** covering all critical infrastructure components.

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
- ✅ Provides colored output and clear pass/fail status
- ✅ Same behavior as CI/CD and pre-commit hooks

### Alternative: Direct Terraform Test Commands

You can also run specific tests directly using Terraform:

```bash
# Test ALB module only
cd infra-ecs
# Follow manual test setup...

# Or use terraform test with filters (requires proper setup)
terraform test -filter=tests/unit/alb.tftest.hcl
```

**Note**: Direct Terraform test commands require proper module initialization and path configuration. The `run-tests.sh` script handles this automatically.

### Run a Specific Test Run

```bash
# Run only the ALB basic configuration test
terraform test -filter=tests/unit/alb.tftest.hcl -verbose
```

### Verbose Output

For detailed output including all assertions:
```bash
terraform test -verbose
```

## Test Output

Successful test output:
```
Testing unit/alb.tftest.hcl... in progress
  run "alb_valid_configuration"... pass
  run "alb_production_configuration"... pass
  run "alb_listeners_configured"... pass
  run "alb_target_group_configuration"... pass
  run "alb_security_group_rules"... pass
  run "alb_resource_tagging"... pass
Testing unit/alb.tftest.hcl... 6/6 passed, 0 failed
```

Failed test output shows which assertion failed:
```
Testing unit/alb.tftest.hcl... in progress
  run "alb_valid_configuration"... fail
    ✗ ALB name should match environment and project name pattern
      Condition: aws_alb.alb.name == "dev-test-project-alb"
      Actual: "test-project-alb"
Testing unit/alb.tftest.hcl... 0/1 passed, 1 failed
```

## Understanding Test Files

### Test File Structure

Each `.tftest.hcl` file contains one or more test runs using **in-place testing**:

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

### Step 1: Determine Test Type

- **Unit Test**: Testing a single module in isolation → Create in `tests/unit/`

### Step 2: Create Test File

```bash
# Create new unit test file
touch infra-ecs/tests/unit/my_module.tftest.hcl
```

### Step 3: Write Test Runs

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

### Step 4: Test Your Tests

```bash
cd infra-ecs/tests
terraform test -filter=tests/unit/my_module.tftest.hcl -verbose
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

### GitHub Actions - ✅ IMPLEMENTED

The project includes automated testing in the CI/CD pipeline. Tests are run:
- ✅ On every push to main branch
- ✅ Before deploying any infrastructure
- ✅ As the first job in the deployment pipeline

**Implementation Location:** [.github/workflows/deploy_aws_infra.yaml](../.github/workflows/deploy_aws_infra.yaml)

The `test-terraform-modules` job runs first and blocks all deployments if tests fail. The job:

1. **Validates module syntax** - Runs `terraform validate` on all modules
2. **Runs unit tests** - Tests each module (ALB, ECS Cluster, ECS Service, ECR)
3. **Reports results** - Provides clear pass/fail status with error messages
4. **Blocks deployment** - All other jobs depend on tests passing

### Job Dependencies

```
test-terraform-modules (runs first)
    ├─> deploy-terraform-state-bucket
    │       ├─> deploy-ecr
    │       │       ├─> build-and-push-app-docker-image-to-ecr
    │       │       ├─> deploy-vpc
    │       │       │       └─> deploy-ecs-cluster
    │       │       │               └─> deploy-alb
    │       │       │                       ├─> deploy-ecs-service
    │       │       │                       └─> deploy-routing
    │       └─> retrieve-ssl
    │               └─> deploy-alb
```

All deployment jobs transitively depend on tests passing.

### Test Job Implementation

The test job uses the centralized test script [infra-ecs/run-tests.sh](../infra-ecs/run-tests.sh):

```yaml
test-terraform-modules:
  name: Test Terraform Modules
  runs-on: ubuntu-latest

  steps:
    - name: Checkout code from the repository
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{env.TERRAFORM_VERSION}}

    - name: Run Terraform module tests
      run: |
        cd infra-ecs
        chmod +x run-tests.sh
        ./run-tests.sh
```

The script:
1. Validates all module syntax with `terraform validate`
2. Runs unit tests for each module (ALB, ECS Cluster, ECS Service, ECR)
3. Provides GitHub Actions annotations (::error::, ::notice::)
4. Exits with error if any test fails

### Pre-Commit Hook Integration - ✅ IMPLEMENTED

Tests also run automatically as a pre-commit hook when committing changes to Terraform files.

**Configuration Location:** [.pre-commit-config.yaml](../.pre-commit-config.yaml)

The pre-commit hook:
- **Triggers on**: Changes to `*.tf` or `*.tftest.hcl` files in `infra-ecs/modules/` or `infra-ecs/tests/`
- **Runs**: The same `run-tests.sh` script used in CI/CD
- **Blocks commits**: If tests fail
- **Provides**: Immediate feedback before pushing code

To skip the test hook (not recommended):
```bash
git commit --no-verify
```

To run tests manually before committing:
```bash
cd infra-ecs
./run-tests.sh
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
- ❌ The `test-terraform-modules` job fails
- 🛑 All deployment jobs are skipped (they depend on tests)
- 📧 GitHub sends notification email
- 🔴 Workflow shows as failed in GitHub UI
- 💬 Error messages indicate which module/test failed

Example failure output:
```
::error::Tests failed for alb module
Testing alb module...
tests/alb.tftest.hcl... fail
  run "alb_valid_configuration"... fail
    ✗ ALB name should match environment and project name pattern
```

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

## Example Test Sessions

### Running Complete Test Suite

```bash
$ cd infra-ecs/tests
$ terraform init
$ terraform test

Testing unit/alb.tftest.hcl... in progress
  run "alb_valid_configuration"... pass
  run "alb_production_configuration"... pass
  run "alb_listeners_configured"... pass
  run "alb_target_group_configuration"... pass
  run "alb_security_group_rules"... pass
  run "alb_resource_tagging"... pass
Testing unit/alb.tftest.hcl... 6/6 passed, 0 failed

Testing unit/ecs_cluster.tftest.hcl... in progress
  run "ecs_cluster_basic_configuration"... pass
  run "ecs_asg_configuration"... pass
  run "ecs_asg_dev_configuration"... pass
  run "ecs_asg_production_configuration"... pass
  run "ecs_launch_template_configuration"... pass
  run "ecs_security_group"... pass
  run "ecs_iam_roles"... pass
Testing unit/ecs_cluster.tftest.hcl... 7/7 passed, 0 failed

Testing unit/ecs_service.tftest.hcl... in progress
  run "ecs_service_basic_configuration"... pass
  run "ecs_task_definition_configuration"... pass
  run "ecs_service_deployment_configuration"... pass
  run "ecs_service_load_balancer_integration"... pass
  run "ecs_service_security_group"... pass
  run "ecs_cloudwatch_logs"... pass
  run "ecs_iam_roles"... pass
Testing unit/ecs_service.tftest.hcl... 8/8 passed, 0 failed

Testing unit/ecr.tftest.hcl... in progress
  run "ecr_repository_basic_configuration"... pass
  run "ecr_repository_tagging"... pass
  run "ecr_lifecycle_policy_exists"... pass
  run "ecr_lifecycle_policy_untagged_images"... pass
  run "ecr_lifecycle_policy_dev_retention"... pass
  run "ecr_lifecycle_policy_prod_retention"... pass
  run "ecr_variable_validation_retention_count"... pass
  run "ecr_variable_validation_environment"... pass
Testing unit/ecr.tftest.hcl... 8/8 passed, 0 failed

Testing unit/ssl.tftest.hcl... in progress
  run "ssl_certificate_basic_configuration"... pass
  run "ssl_validation_records_configuration"... pass
  run "ssl_certificate_validation_configuration"... pass
  run "ssl_production_environment"... pass
  run "ssl_san_wildcard_coverage"... pass
  run "ssl_validation_method_dns_only"... pass
Testing unit/ssl.tftest.hcl... 6/6 passed, 0 failed

Summary: 34/34 tests passed, 0 failed
```

### Testing Single Module

```bash
$ cd infra-ecs/tests
$ terraform test -filter=tests/unit/ecr.tftest.hcl -verbose

Testing unit/ecr.tftest.hcl... in progress
  run "ecr_repository_basic_configuration"...
    ✓ ECR repository name should match environment and project pattern
    ✓ ECR repository should have IMMUTABLE tag mutability for image integrity
    ✓ ECR repository should have scan_on_push enabled for security
  run "ecr_repository_basic_configuration"... pass

  run "ecr_lifecycle_policy_dev_retention"...
    ✓ Lifecycle policy should use dev- tag prefix for dev environment
    ✓ Lifecycle policy should use configured retention count for dev
  run "ecr_lifecycle_policy_dev_retention"... pass

Testing unit/ecr.tftest.hcl... 8/8 passed, 0 failed
```

## Summary

- **34 test runs** across 5 test files validate all critical infrastructure modules
- **Unit tests** verify individual module configuration and behavior
- **Plan mode** tests avoid AWS costs while validating configuration
- **Clear assertions** with descriptive error messages aid debugging
- **Comprehensive coverage** includes security, naming, tagging, and functionality

Run `./run-tests.sh` before committing changes to catch issues early!

## Maintenance

**Last Updated:** 2025-11-28

Review and update this documentation when:
- Adding new test files or test patterns
- Changing test infrastructure or CI/CD integration
- Updating Terraform version (check for new testing features)
- Receiving feedback about unclear testing procedures
