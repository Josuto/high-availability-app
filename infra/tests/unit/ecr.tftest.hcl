# Test suite for ECR module
# Tests ECR repository configuration, security settings, and lifecycle policies

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "ecr_repository_basic_configuration" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "dev"
  }

  # Test repository name follows naming convention
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.name == "dev-test-project-ecr-repository"
    error_message = "ECR repository name should match environment and project pattern"
  }

  # Test image tag mutability is IMMUTABLE for security
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.image_tag_mutability == "IMMUTABLE"
    error_message = "ECR repository should have IMMUTABLE tag mutability for image integrity"
  }

  # Test image scanning is enabled
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.image_scanning_configuration[0].scan_on_push == true
    error_message = "ECR repository should have scan_on_push enabled for security"
  }
}

run "ecr_repository_tagging" {
  command = plan

  variables {
    project_name = "my-app"
    environment  = "prod"
  }

  # Test repository has required tags
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.tags["Project"] == "my-app"
    error_message = "ECR repository should have Project tag"
  }

  assert {
    condition     = aws_ecr_repository.app_ecr_repository.tags["Environment"] == "prod"
    error_message = "ECR repository should have Environment tag"
  }
}

run "ecr_lifecycle_policy_exists" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "dev"
  }

  # Test lifecycle policy is attached to repository
  assert {
    condition     = aws_ecr_lifecycle_policy.ecr_policy.repository == "dev-test-project-ecr-repository"
    error_message = "Lifecycle policy should be attached to correct repository"
  }

  # Test policy exists
  assert {
    condition     = length(aws_ecr_lifecycle_policy.ecr_policy.policy) > 0
    error_message = "Lifecycle policy should be defined"
  }
}

run "ecr_lifecycle_policy_untagged_images" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "dev"
  }

  # Test policy contains rule for untagged images
  assert {
    condition     = can(regex("untagged", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should include rule for untagged images"
  }

  # Test policy keeps 1 untagged image
  assert {
    condition     = can(regex("\"countNumber\"\\s*:\\s*1", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should keep 1 untagged image"
  }
}

run "ecr_lifecycle_policy_dev_retention" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "dev"
    image_retention_max_count = {
      dev  = 5
      prod = 10
    }
  }

  # Test policy contains dev tag prefix
  assert {
    condition     = can(regex("dev-", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should use dev- tag prefix for dev environment"
  }

  # Test policy uses correct retention count for dev
  assert {
    condition     = can(regex("\"countNumber\"\\s*:\\s*5", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should use configured retention count for dev"
  }
}

run "ecr_lifecycle_policy_prod_retention" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "prod"
    image_retention_max_count = {
      dev  = 3
      prod = 20
    }
  }

  # Test policy contains prod tag prefix
  assert {
    condition     = can(regex("prod-", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should use prod- tag prefix for prod environment"
  }

  # Test policy uses correct retention count for prod
  assert {
    condition     = can(regex("\"countNumber\"\\s*:\\s*20", aws_ecr_lifecycle_policy.ecr_policy.policy))
    error_message = "Lifecycle policy should use configured retention count for prod"
  }
}

run "ecr_variable_validation_retention_count" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "dev"
    image_retention_max_count = {
      dev  = 3
      prod = 10
    }
  }

  # Test valid retention counts are accepted
  assert {
    condition     = length(aws_ecr_repository.app_ecr_repository.name) > 0
    error_message = "Valid retention counts should be accepted"
  }
}

run "ecr_variable_validation_environment" {
  command = plan

  variables {
    project_name = "test-project"
    environment  = "prod"
  }

  # Test valid environment is accepted
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.name == "prod-test-project-ecr-repository"
    error_message = "Valid environment 'prod' should be accepted"
  }
}
