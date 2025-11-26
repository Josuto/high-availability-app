# This recipe defines an ECS Task Definition and then an ECS Service to run a containerized application, integrating with an ALB.

# Defines the application's container configuration for ECS i.e., the blueprint for your application containers, including
# their images, ports, CPU/memory allocation, and logging configuration.
resource "aws_ecs_task_definition" "ecs_service_taskdef" {
  family                   = var.container_name # A family groups together revisions of a task definition. When you make changes to a task definition, ECS creates a new revision within the same family
  network_mode             = "awsvpc"           # ALB reaches task directly (not EC2 instance)
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu_limit                            # Limit CPU usage at task level
  memory                   = var.memory_limit                         # Limit memory usage at task level
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # ECS agent IAM role so that ECS can run the task (pull image from ECR, write logs to CloudWatch)
  task_role_arn            = var.task_role_arn                        # App IAM role if the app needs AWS access e.g., write logs to CloudWatch, access S3 buckets, etc.

  container_definitions = templatefile("${path.module}/ecs-service.json.tpl", { # It takes the dynamically generated JSON string from the given TPL and uses it to define the containers that will run as part of this task
    ecr_app_image  = var.ecr_app_image,
    container_name = var.container_name,
    container_port = var.container_port,
    cpu_limit      = var.cpu_limit
    memory_limit   = var.memory_limit
    log_group      = var.log_group,
    aws_region     = var.aws_region
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Data source used to retrieve the latest revision number of the task definition. This is particularly useful for ensuring that the
# `aws_ecs_service` resource always points to the most up-to-date task definition, whether it's the one just created/updated by Terraform
# or a previous revision that might still be active.
data "aws_ecs_task_definition" "ecs_service" {
  task_definition = aws_ecs_task_definition.ecs_service_taskdef.family # Look for the latest active revision of the task definition that matches that family name
  depends_on      = [aws_ecs_task_definition.ecs_service_taskdef]      # Depends on the previously defined `ecs_service_taskdef`
}

# This resource manages the desired number of running tasks of a specific task definition within an ECS cluster.
resource "aws_ecs_service" "ecs_service" {
  name    = "${var.environment}-${var.project_name}-ecs-service" # Name of the ECS service
  cluster = var.ecs_cluster_arn                                  # Associates this service with a specific ECS cluster
  # This construct ensures that the ECS service always points to the most current active revision of the task definition within that family
  task_definition                    = "${aws_ecs_task_definition.ecs_service_taskdef.family}:${max(aws_ecs_task_definition.ecs_service_taskdef.revision, data.aws_ecs_task_definition.ecs_service.revision)}"
  desired_count                      = var.ecs_task_desired_count             # The number of tasks that you want to run for this service. ECS will automatically maintain this number
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent # Lower limit of healthy tasks that must be running during deployment so that the service remains available
  deployment_maximum_percent         = var.deployment_maximum_percent         # Upper limit of health tasks that must be running during deployment. This helps control the rollout speed and resource consumption during updates

  # List of rules ECS applies in order when deciding task placement in the EC2 instances based on environment
  dynamic "ordered_placement_strategy" {
    # Select the list of strategies for the current environment ("dev" or "prod")
    for_each = var.ordered_placement_strategies[var.environment]

    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  # Link to the Capacity Provider for EC2 placement
  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  # Link to the ALB
  load_balancer {
    target_group_arn = var.alb_target_group_id # Links this service to a target group defined elsewhere
    container_name   = var.container_name      # The name of the container within your task definition that exposes the port to the load balancer. Important: The name property inside your `ecs-service.json.tpl` container definition must match this name
    container_port   = var.container_port      # The port on the specified container that the load balancer should forward traffic to. Important: This port must be exposed in your `ecs-service.json.tpl` container definition's portMappings
  }

  network_configuration {
    subnets          = var.vpc_private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false # Do not expose task IPs outside the private network
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
