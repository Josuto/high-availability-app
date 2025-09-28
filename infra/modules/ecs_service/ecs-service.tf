# This recipe defines an ECS Task Definition and then an ECS Service to run a containerized application, integrating with an ALB.

# Defines the application's container configuration for ECS i.e., the blueprint for your application containers, including 
# their images, ports, CPU/memory allocation, and logging configuration.
resource "aws_ecs_task_definition" "ecs-service-taskdef" {
  family                = var.container_name # A family groups together revisions of a task definition. When you make changes to a task definition, ECS creates a new revision within the same family
  container_definitions = templatefile("${path.module}/ecs-service.json.tpl", { # It takes the dynamically generated JSON string from the given TPL and uses it to define the containers that will run as part of this task
    ecr_app_image       = var.ecr_app_image,
    container_name      = var.container_name,
    container_port      = var.container_port,
    log_group           = var.log_group,
    aws_region          = var.aws_region
  })
  task_role_arn         = var.task_role_arn # Specifies the ARN of an IAM role that the ECS tasks will assume. This role grants permissions to the containers (e.g., to write logs to CloudWatch, access S3 buckets, etc.)

  tags = {
    Project = var.project_name
  }
}

# Data source used to retrieve the latest revision number of the task definition. This is particularly useful for ensuring that the 
# `aws_ecs_service` resource always points to the most up-to-date task definition, whether it's the one just created/updated by Terraform 
# or a previous revision that might still be active.
data "aws_ecs_task_definition" "ecs-service" {
  task_definition = aws_ecs_task_definition.ecs-service-taskdef.family # Look for the latest active revision of the task definition that matches that family name
  depends_on      = [aws_ecs_task_definition.ecs-service-taskdef] # Depends on the previously defined `ecs-service-taskdef`
}

# This resource manages the desired number of running tasks of a specific task definition within an ECS cluster.
resource "aws_ecs_service" "ecs-service" {
  name                               = "${var.container_name}-ecs-service" # Name of the ECS service
  cluster                            = var.ecs_cluster_arn # Associates this service with a specific ECS cluster
  # This construct ensures that the ECS service always points to the most current active revision of the task definition within that family
  task_definition                    = "${aws_ecs_task_definition.ecs-service-taskdef.family}:${max("${aws_ecs_task_definition.ecs-service-taskdef.revision}", "${data.aws_ecs_task_definition.ecs-service.revision}")}"
  iam_role                           = aws_iam_role.ecs-service-role.arn # IAM role that grants the ECS service permissions to call other AWS services on your behalf (e.g., registering tasks with the load balancer, interacting with CloudWatch logs)
  desired_count                      = var.ecs_task_desired_count # The number of tasks that you want to run for this service. ECS will automatically maintain this number
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent # Lower limit of healthy tasks that must be running during deployment so that the service remains available
  deployment_maximum_percent         = var.deployment_maximum_percent # Upper limit of health tasks that must be running during deployment. This helps control the rollout speed and resource consumption during updates

  # Link to the Capacity Provider for EC2 placement
  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 1
  }

  # Link to the ALB
  load_balancer { 
    target_group_arn = var.alb_target_group_id # Links this service to a target group defined elsewhere
    container_name   = var.container_name # The name of the container within your task definition that exposes the port to the load balancer. Important: The name property inside your `ecs-service.json.tpl` container definition must match this name
    container_port   = var.container_port # The port on the specified container that the load balancer should forward traffic to. Important: This port must be exposed in your `ecs-service.json.tpl` container definition's portMappings
  }

  tags = {
    Project = var.project_name
  }
}
