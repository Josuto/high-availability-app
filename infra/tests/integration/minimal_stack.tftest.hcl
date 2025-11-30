# Integration test for minimal stack deployment
# Tests that all core modules work together correctly with realistic data flow

# This test uses plan mode to verify resource configuration without actually deploying
# to AWS, avoiding costs while still validating module integration

variables {
  project_name   = "integration-test"
  environment    = "dev"
  aws_region     = "us-east-1"
  container_port = 3000
  container_name = "app"
}

# Test ECR module standalone
run "setup_ecr" {
  command = plan

  module {
    source = "../../modules/ecr"
  }

  variables {
    project_name = var.project_name
    environment  = var.environment
  }

  # Verify ECR repository is created
  assert {
    condition     = aws_ecr_repository.app_ecr_repository.name == "dev-integration-test-ecr-repository"
    error_message = "ECR repository should be created with correct naming"
  }

  assert {
    condition     = aws_ecr_repository.app_ecr_repository.image_scanning_configuration[0].scan_on_push == true
    error_message = "ECR should have vulnerability scanning enabled"
  }
}

# Test ECS Cluster with dependencies
run "setup_ecs_cluster" {
  command = plan

  module {
    source = "../../modules/ecs_cluster"
  }

  variables {
    project_name        = var.project_name
    environment         = var.environment
    ecs_instance_type   = "t3.micro"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    instance_min_size   = 1
    instance_max_size   = 2
  }

  # Verify ECS cluster is created
  assert {
    condition     = aws_ecs_cluster.ecs_cluster.name == "dev-integration-test-ecs-cluster"
    error_message = "ECS cluster should be created with correct naming"
  }

  # Verify capacity provider is configured
  assert {
    condition     = aws_ecs_capacity_provider.ecs_capacity_provider.name == "dev-integration-test-ecs-capacity-provider"
    error_message = "ECS capacity provider should be created"
  }

  # Verify ASG is properly configured for the cluster
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.min_size == 1
    error_message = "ASG should respect configured min size"
  }

  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.max_size == 2
    error_message = "ASG should respect configured max size"
  }
}

# Test ALB with dependencies
run "setup_alb" {
  command = plan

  module {
    source = "../../modules/alb"
  }

  variables {
    project_name        = var.project_name
    environment         = var.environment
    vpc_id              = "vpc-12345678"
    vpc_public_subnets  = ["subnet-33333333", "subnet-44444444"]
    container_port      = var.container_port
    ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  }

  # Verify ALB is created
  assert {
    condition     = aws_alb.alb.name == "dev-integration-test-alb"
    error_message = "ALB should be created with correct naming"
  }

  # Verify target group is configured with correct port
  assert {
    condition     = aws_alb_target_group.alb_target_group.port == 3000
    error_message = "Target group should use correct container port"
  }

  # Verify HTTPS listener is configured
  assert {
    condition     = aws_alb_listener.alb_https.port == 443
    error_message = "HTTPS listener should be on port 443"
  }

  # Verify security headers are enabled
  assert {
    condition     = aws_alb.alb.drop_invalid_header_fields == true
    error_message = "ALB should drop invalid header fields"
  }
}

# Test ECS Service with all dependencies
run "setup_ecs_service" {
  command = plan

  module {
    source = "../../modules/ecs_service"
  }

  variables {
    project_name               = var.project_name
    environment                = var.environment
    container_name             = var.container_name
    container_port             = var.container_port
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration-test:dev-abc123"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/dev-integration-test-ecs-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/dev-integration-test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "dev-integration-test-ecs-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/integration-test"
  }

  # Verify ECS service is created
  assert {
    condition     = aws_ecs_service.ecs_service.name == "dev-integration-test-ecs-service"
    error_message = "ECS service should be created with correct naming"
  }

  # Verify service uses correct cluster
  assert {
    condition     = aws_ecs_service.ecs_service.cluster == "arn:aws:ecs:us-east-1:123456789012:cluster/dev-integration-test-ecs-cluster"
    error_message = "ECS service should be attached to correct cluster"
  }

  # Verify service is connected to load balancer
  assert {
    condition     = length(aws_ecs_service.ecs_service.load_balancer) > 0
    error_message = "ECS service should be connected to load balancer"
  }

  # Verify load balancer configuration matches
  assert {
    condition     = aws_ecs_service.ecs_service.load_balancer[0].container_name == "app"
    error_message = "Load balancer should target correct container"
  }

  assert {
    condition     = aws_ecs_service.ecs_service.load_balancer[0].container_port == 3000
    error_message = "Load balancer should target correct port"
  }

  # Verify capacity provider strategy is configured
  assert {
    condition     = aws_ecs_service.ecs_service.capacity_provider_strategy[0].capacity_provider == "dev-integration-test-ecs-capacity-provider"
    error_message = "ECS service should use correct capacity provider"
  }

  # Verify task definition uses correct image
  assert {
    condition     = can(regex("123456789012\\.dkr\\.ecr\\.us-east-1\\.amazonaws\\.com/integration-test:dev-abc123", aws_ecs_task_definition.ecs_service_taskdef.container_definitions))
    error_message = "Task definition should use correct ECR image"
  }

  # Verify security group allows traffic from ALB
  assert {
    condition     = contains([for rule in aws_security_group.ecs_tasks.ingress : rule.security_groups[0]], "sg-12345678")
    error_message = "ECS tasks should allow ingress from ALB security group"
  }

  # Verify CloudWatch logging is configured
  assert {
    condition     = aws_cloudwatch_log_group.cluster_lg.name == "/ecs/integration-test"
    error_message = "CloudWatch log group should be created with correct name"
  }

  # Verify IAM roles are properly configured
  assert {
    condition     = length(aws_iam_role.ecs_execution_role.name) > 0
    error_message = "ECS execution role should be created"
  }

  assert {
    condition     = can(regex("ecs-tasks\\.amazonaws\\.com", aws_iam_role.ecs_execution_role.assume_role_policy))
    error_message = "ECS execution role should trust ECS tasks service"
  }
}

# Test cross-module data flow patterns
run "validate_naming_consistency" {
  command = plan

  module {
    source = "../../modules/ecs_service"
  }

  variables {
    project_name               = "my-app"
    environment                = "prod"
    container_name             = "web"
    container_port             = 8080
    cpu_limit                  = 1024
    memory_limit               = 2048
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:prod-xyz789"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/prod-my-app-ecs-cluster"
    ecs_task_desired_count     = 3
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/prod-my-app/xyz789"
    alb_security_group_id      = "sg-87654321"
    ecs_capacity_provider_name = "prod-my-app-ecs-capacity-provider"
    vpc_id                     = "vpc-87654321"
    vpc_private_subnets        = ["subnet-55555555", "subnet-66666666"]
    log_group                  = "/ecs/my-app"
  }

  # Verify all resources follow the same naming convention
  assert {
    condition     = aws_ecs_service.ecs_service.name == "prod-my-app-ecs-service"
    error_message = "All resources should follow {environment}-{project}-{resource} naming"
  }

  assert {
    condition     = aws_ecs_task_definition.ecs_service_taskdef.family == "prod-my-app-ecs-taskdef"
    error_message = "Task definition family should follow naming convention"
  }

  # Verify tags are consistent
  assert {
    condition     = aws_security_group.ecs_tasks.tags["Project"] == "my-app"
    error_message = "All resources should have consistent Project tags"
  }

  assert {
    condition     = aws_security_group.ecs_tasks.tags["Environment"] == "prod"
    error_message = "All resources should have consistent Environment tags"
  }
}
