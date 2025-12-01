# Test suite for SSL/ACM Certificate module
# Tests ACM certificate configuration, DNS validation, SANs, and lifecycle rules

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "ssl_certificate_basic_configuration" {
  command = plan

  variables {
    project_name             = "test-project"
    root_domain_name         = "example.com"
    subject_alternative_name = "*.example.com"
    hosted_zone_id           = "Z1234567890ABC"
    environment              = "dev"
  }

  # Test certificate is created with correct domain
  assert {
    condition     = aws_acm_certificate.certificate.domain_name == "example.com"
    error_message = "Certificate domain should match root domain name"
  }

  # Test certificate uses DNS validation (not email)
  assert {
    condition     = aws_acm_certificate.certificate.validation_method == "DNS"
    error_message = "Certificate must use DNS validation method for automation"
  }

  # Test SAN is included for wildcard domain
  assert {
    condition     = contains(aws_acm_certificate.certificate.subject_alternative_names, "*.example.com")
    error_message = "Certificate should include wildcard domain as SAN"
  }

  # Note: lifecycle meta-arguments cannot be tested in assertions
  # The create_before_destroy setting is verified through code review

  # Test tags are applied
  assert {
    condition     = aws_acm_certificate.certificate.tags["Project"] == "test-project"
    error_message = "Certificate should have Project tag"
  }

  assert {
    condition     = aws_acm_certificate.certificate.tags["Environment"] == "dev"
    error_message = "Certificate should have Environment tag"
  }
}

run "ssl_validation_records_configuration" {
  command = plan

  variables {
    project_name             = "test-project"
    root_domain_name         = "example.com"
    subject_alternative_name = "*.example.com"
    hosted_zone_id           = "Z1234567890ABC"
    environment              = "dev"
  }

  # Test validation records use correct hosted zone
  assert {
    condition     = alltrue([for record in aws_route53_record.certificate_validation : record.zone_id == "Z1234567890ABC"])
    error_message = "All validation records should use the provided hosted zone ID"
  }

  # Test validation records have allow_overwrite enabled
  assert {
    condition     = alltrue([for record in aws_route53_record.certificate_validation : record.allow_overwrite == true])
    error_message = "Validation records should allow overwrite for redeployments"
  }

  # Test validation records have short TTL
  assert {
    condition     = alltrue([for record in aws_route53_record.certificate_validation : record.ttl == 60])
    error_message = "Validation records should have TTL of 60 seconds for faster propagation"
  }
}

run "ssl_certificate_validation_configuration" {
  command = plan

  variables {
    project_name             = "test-project"
    root_domain_name         = "example.com"
    subject_alternative_name = "*.example.com"
    hosted_zone_id           = "Z1234567890ABC"
    environment              = "dev"
  }

  # Note: aws_acm_certificate_validation resource values are computed
  # and cannot be tested in plan mode assertions
  # The validation workflow is verified through code review and integration tests

  # Test that validation resource is defined (existence check)
  assert {
    condition     = length([for k, v in aws_route53_record.certificate_validation : v]) > 0
    error_message = "Validation records should be created for certificate validation"
  }
}

run "ssl_production_environment" {
  command = plan

  variables {
    project_name             = "prod-project"
    root_domain_name         = "production.com"
    subject_alternative_name = "*.production.com"
    hosted_zone_id           = "Z9876543210XYZ"
    environment              = "prod"
  }

  # Test production certificate has correct domain
  assert {
    condition     = aws_acm_certificate.certificate.domain_name == "production.com"
    error_message = "Production certificate should use production domain"
  }

  # Test production environment tag
  assert {
    condition     = aws_acm_certificate.certificate.tags["Environment"] == "prod"
    error_message = "Certificate should have prod environment tag"
  }
}

run "ssl_san_wildcard_coverage" {
  command = plan

  variables {
    project_name             = "test-project"
    root_domain_name         = "myapp.com"
    subject_alternative_name = "*.myapp.com"
    hosted_zone_id           = "Z1111111111111"
    environment              = "dev"
  }

  # Test root domain is the primary domain
  assert {
    condition     = aws_acm_certificate.certificate.domain_name == "myapp.com"
    error_message = "Root domain should be the primary certificate domain"
  }

  # Test wildcard SAN covers subdomains
  assert {
    condition     = contains(aws_acm_certificate.certificate.subject_alternative_names, "*.myapp.com")
    error_message = "Wildcard SAN should be included to cover all subdomains"
  }
}

run "ssl_validation_method_dns_only" {
  command = plan

  variables {
    project_name             = "test-project"
    root_domain_name         = "secure.com"
    subject_alternative_name = "*.secure.com"
    hosted_zone_id           = "Z2222222222222"
    environment              = "prod"
  }

  # Test validation is DNS (critical for automation)
  assert {
    condition     = aws_acm_certificate.certificate.validation_method == "DNS"
    error_message = "Certificate must use DNS validation for automated deployments"
  }

  # Ensure email validation is NOT used
  assert {
    condition     = aws_acm_certificate.certificate.validation_method != "EMAIL"
    error_message = "Email validation should never be used (requires manual intervention)"
  }
}
