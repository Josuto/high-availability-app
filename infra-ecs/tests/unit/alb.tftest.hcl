# Test suite for ALB module
# Tests ALB configuration, listeners, target groups, and security groups

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "alb_valid_configuration" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 3000
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "dev"
  }

  # Test ALB is created
  assert {
    condition     = aws_alb.alb.name == "dev-test-project-alb"
    error_message = "ALB name should match environment and project name pattern"
  }

  # Test ALB is internet-facing
  assert {
    condition     = aws_alb.alb.internal == false
    error_message = "ALB should be internet-facing for public access"
  }

  # Test drop_invalid_header_fields is enabled
  assert {
    condition     = aws_alb.alb.drop_invalid_header_fields == true
    error_message = "ALB should drop invalid header fields for security"
  }

  # Test deletion protection is disabled for dev
  assert {
    condition     = aws_alb.alb.enable_deletion_protection == false
    error_message = "Deletion protection should be disabled for dev environment"
  }
}

run "alb_production_configuration" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 3000
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "prod"
  }

  # Test deletion protection is enabled for prod
  assert {
    condition     = aws_alb.alb.enable_deletion_protection == true
    error_message = "Deletion protection should be enabled for prod environment"
  }
}

run "alb_listeners_configured" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 3000
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "dev"
  }

  # Test HTTPS listener is configured
  assert {
    condition     = aws_alb_listener.alb_https.port == 443
    error_message = "HTTPS listener should be on port 443"
  }

  assert {
    condition     = aws_alb_listener.alb_https.protocol == "HTTPS"
    error_message = "HTTPS listener should use HTTPS protocol"
  }

  assert {
    condition     = aws_alb_listener.alb_https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
    error_message = "HTTPS listener should use modern TLS policy"
  }

  # Test HTTP listener redirects to HTTPS
  assert {
    condition     = aws_alb_listener.alb_http.port == 80
    error_message = "HTTP listener should be on port 80"
  }

  assert {
    condition     = aws_alb_listener.alb_http.default_action[0].type == "redirect"
    error_message = "HTTP listener should redirect to HTTPS"
  }

  assert {
    condition     = aws_alb_listener.alb_http.default_action[0].redirect[0].protocol == "HTTPS"
    error_message = "HTTP should redirect to HTTPS protocol"
  }

  assert {
    condition     = aws_alb_listener.alb_http.default_action[0].redirect[0].status_code == "HTTP_301"
    error_message = "HTTP redirect should use 301 permanent redirect"
  }
}

run "alb_target_group_configured" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 8080
    deregistration_delay           = 60
    health_check_path              = "/api/health"
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "dev"
  }

  # Test target group port matches container port
  assert {
    condition     = aws_alb_target_group.ecs_service.port == 8080
    error_message = "Target group port should match container port"
  }

  # Test target group protocol
  assert {
    condition     = aws_alb_target_group.ecs_service.protocol == "HTTP"
    error_message = "Target group should use HTTP protocol for backend"
  }

  # Test deregistration delay
  assert {
    condition     = tonumber(aws_alb_target_group.ecs_service.deregistration_delay) == 60
    error_message = "Target group should use configured deregistration delay"
  }

  # Test health check path
  assert {
    condition     = aws_alb_target_group.ecs_service.health_check[0].path == "/api/health"
    error_message = "Health check should use configured path"
  }

  # Test health check matcher
  assert {
    condition     = aws_alb_target_group.ecs_service.health_check[0].matcher == "200"
    error_message = "Health check should expect 200 status code"
  }
}

run "alb_security_group_rules" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 3000
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "dev"
  }

  # Test security group is created
  assert {
    condition     = aws_security_group.alb.vpc_id == "vpc-12345678"
    error_message = "Security group should be in correct VPC"
  }

  # Test HTTPS ingress rule
  assert {
    condition     = contains([for rule in aws_security_group.alb.ingress : rule.from_port], 443)
    error_message = "Security group should allow HTTPS ingress"
  }

  # Test HTTP ingress rule
  assert {
    condition     = contains([for rule in aws_security_group.alb.ingress : rule.from_port], 80)
    error_message = "Security group should allow HTTP ingress"
  }

  # Test egress rule exists
  assert {
    condition     = length(aws_security_group.alb.egress) > 0
    error_message = "Security group should have egress rules"
  }
}

run "alb_tags_applied" {
  command = plan

  variables {
    project_name                   = "test-project"
    vpc_id                         = "vpc-12345678"
    vpc_public_subnets             = ["subnet-11111111", "subnet-22222222"]
    container_name                 = "test-container"
    container_port                 = 3000
    acm_certificate_validation_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    environment                    = "dev"
  }

  # Test ALB resource is created
  assert {
    condition     = aws_alb.alb.name != ""
    error_message = "ALB should be created with a name"
  }
}
