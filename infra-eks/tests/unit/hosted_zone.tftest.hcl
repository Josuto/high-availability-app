# Test suite for Hosted Zone module
# Tests Route53 hosted zone configuration and environment-specific settings

provider "aws" {
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "hosted_zone_basic_configuration" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "example.com"
    environment      = "dev"
  }

  # Test hosted zone name matches root domain
  assert {
    condition     = aws_route53_zone.domain_zone.name == "example.com"
    error_message = "Hosted zone name should match root domain name"
  }

  # Test hosted zone comment is set
  assert {
    condition     = aws_route53_zone.domain_zone.comment == "Hosted zone for the domain"
    error_message = "Hosted zone should have descriptive comment"
  }
}

run "hosted_zone_dev_force_destroy" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "dev.example.com"
    environment      = "dev"
    force_destroy = {
      dev  = true
      prod = false
    }
  }

  # Test force_destroy is enabled for dev
  assert {
    condition     = aws_route53_zone.domain_zone.force_destroy == true
    error_message = "force_destroy should be true for dev environment to allow cleanup"
  }
}

run "hosted_zone_prod_force_destroy" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "prod.example.com"
    environment      = "prod"
    force_destroy = {
      dev  = true
      prod = false
    }
  }

  # Test force_destroy is disabled for prod
  assert {
    condition     = aws_route53_zone.domain_zone.force_destroy == false
    error_message = "force_destroy should be false for prod environment to prevent accidental deletion"
  }
}

run "hosted_zone_tagging" {
  command = plan

  variables {
    project_name     = "my-app"
    root_domain_name = "myapp.com"
    environment      = "prod"
  }

  override_resource {
    target = aws_route53_zone.domain_zone
    values = {
      tags = {
        Project     = "my-app"
        Environment = "prod"
        ManagedBy   = "Terraform"
        Module      = "hosted_zone"
      }
    }
  }

  # Test Project tag is set
  assert {
    condition     = aws_route53_zone.domain_zone.tags["Project"] == "my-app"
    error_message = "Hosted zone should have Project tag"
  }

  # Test Environment tag is set
  assert {
    condition     = aws_route53_zone.domain_zone.tags["Environment"] == "prod"
    error_message = "Hosted zone should have Environment tag"
  }

  # Test ManagedBy tag is set
  assert {
    condition     = aws_route53_zone.domain_zone.tags["ManagedBy"] == "Terraform"
    error_message = "Hosted zone should have ManagedBy tag"
  }

  # Test Module tag is set
  assert {
    condition     = aws_route53_zone.domain_zone.tags["Module"] == "hosted_zone"
    error_message = "Hosted zone should have Module tag"
  }
}

run "hosted_zone_subdomain" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "api.example.com"
    environment      = "dev"
  }

  # Test hosted zone accepts subdomain as root
  assert {
    condition     = aws_route53_zone.domain_zone.name == "api.example.com"
    error_message = "Hosted zone should accept subdomain as root domain name"
  }
}

run "hosted_zone_environment_validation" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "example.com"
    environment      = "prod"
  }

  # Test valid environment is accepted
  assert {
    condition     = aws_route53_zone.domain_zone.name == "example.com"
    error_message = "Valid environment 'prod' should be accepted"
  }
}

run "hosted_zone_custom_force_destroy_values" {
  command = plan

  variables {
    project_name     = "test-project"
    root_domain_name = "custom.example.com"
    environment      = "dev"
    force_destroy = {
      dev  = false
      prod = false
    }
  }

  # Test custom force_destroy values are respected
  assert {
    condition     = aws_route53_zone.domain_zone.force_destroy == false
    error_message = "Custom force_destroy values should be respected"
  }
}
