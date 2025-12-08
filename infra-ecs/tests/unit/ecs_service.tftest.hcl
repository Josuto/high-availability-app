# Test suite for ECS Service module
# Tests ECS task definition, service configuration, auto-scaling, and security

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "ecs_service_basic_configuration" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 3000
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test ECS service is created
  assert {
    condition     = aws_ecs_service.ecs_service.name == "dev-test-project-ecs-service"
    error_message = "ECS service name should match environment and project pattern"
  }

  # Test desired count matches input
  assert {
    condition     = aws_ecs_service.ecs_service.desired_count == 2
    error_message = "ECS service desired count should match configured value"
  }

  # Test service has capacity provider configured
  assert {
    condition     = length(aws_ecs_service.ecs_service.capacity_provider_strategy) > 0
    error_message = "ECS service should use capacity provider strategy"
  }
}

run "ecs_task_definition_configuration" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 8080
    cpu_limit                  = 1024
    memory_limit               = 2048
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:v1.0"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 3
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test task definition family name
  assert {
    condition     = aws_ecs_task_definition.ecs_service_taskdef.family == "app"
    error_message = "Task definition family should match container name"
  }

  # Test CPU configuration
  assert {
    condition     = tonumber(aws_ecs_task_definition.ecs_service_taskdef.cpu) == 1024
    error_message = "Task definition CPU should match configured value"
  }

  # Test memory configuration
  assert {
    condition     = tonumber(aws_ecs_task_definition.ecs_service_taskdef.memory) == 2048
    error_message = "Task definition memory should match configured value"
  }

  # Test network mode
  assert {
    condition     = aws_ecs_task_definition.ecs_service_taskdef.network_mode == "awsvpc"
    error_message = "Task definition should use awsvpc network mode"
  }

  # Test container definitions include correct image
  assert {
    condition     = can(regex("123456789012\\.dkr\\.ecr\\.us-east-1\\.amazonaws\\.com/test:v1\\.0", aws_ecs_task_definition.ecs_service_taskdef.container_definitions))
    error_message = "Task definition should use correct ECR image"
  }

  # Test container definitions include correct port
  assert {
    condition     = can(regex("\"containerPort\":\\s*8080", aws_ecs_task_definition.ecs_service_taskdef.container_definitions))
    error_message = "Task definition should expose correct container port"
  }
}

run "ecs_service_deployment_configuration" {
  command = plan

  variables {
    project_name                       = "test-project"
    container_name                     = "app"
    container_port                     = 3000
    cpu_limit                          = 512
    memory_limit                       = 1024
    ecr_app_image                      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn                    = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count             = 2
    deployment_minimum_healthy_percent = 50
    deployment_maximum_percent         = 200
    alb_target_group_id                = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id              = "sg-12345678"
    ecs_capacity_provider_name         = "test-capacity-provider"
    vpc_id                             = "vpc-12345678"
    vpc_private_subnets                = ["subnet-11111111", "subnet-22222222"]
    log_group                          = "/ecs/test-project"
    environment                        = "dev"
  }

  # Test deployment minimum healthy percent
  assert {
    condition     = aws_ecs_service.ecs_service.deployment_minimum_healthy_percent == 50
    error_message = "ECS service should use configured minimum healthy percent"
  }

  # Test deployment maximum percent
  assert {
    condition     = aws_ecs_service.ecs_service.deployment_maximum_percent == 200
    error_message = "ECS service should use configured maximum percent"
  }
}

run "ecs_service_load_balancer_integration" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 3000
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test load balancer is configured
  assert {
    condition     = length(aws_ecs_service.ecs_service.load_balancer) > 0
    error_message = "ECS service should have load balancer configured"
  }
}

run "ecs_service_security_group" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 3000
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-87654321"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test security group is in correct VPC
  assert {
    condition     = aws_security_group.ecs_tasks.vpc_id == "vpc-12345678"
    error_message = "ECS tasks security group should be in correct VPC"
  }

  # Test security group name follows naming convention
  assert {
    condition     = length(aws_security_group.ecs_tasks.name) > 0
    error_message = "ECS tasks security group should have a name"
  }
}

run "ecs_cloudwatch_logs" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 3000
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test CloudWatch log group is created
  assert {
    condition     = aws_cloudwatch_log_group.cluster_lg.name == "/ecs/test-project"
    error_message = "CloudWatch log group should use configured name"
  }
}

run "ecs_iam_roles" {
  command = plan

  variables {
    project_name               = "test-project"
    container_name             = "app"
    container_port             = 3000
    cpu_limit                  = 512
    memory_limit               = 1024
    ecr_app_image              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:latest"
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    ecs_task_desired_count     = 2
    alb_target_group_id        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/abc123"
    alb_security_group_id      = "sg-12345678"
    ecs_capacity_provider_name = "test-capacity-provider"
    vpc_id                     = "vpc-12345678"
    vpc_private_subnets        = ["subnet-11111111", "subnet-22222222"]
    log_group                  = "/ecs/test-project"
    environment                = "dev"
  }

  # Test execution role is created
  assert {
    condition     = length(aws_iam_role.ecs_task_execution_role.name) > 0
    error_message = "ECS execution role should be created"
  }

  # Test execution role has ECS trust relationship
  assert {
    condition     = can(regex("ecs-tasks\\.amazonaws\\.com", aws_iam_role.ecs_task_execution_role.assume_role_policy))
    error_message = "ECS execution role should trust ECS tasks service"
  }
}
