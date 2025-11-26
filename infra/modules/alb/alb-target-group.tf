# A Target Group acts as a logical grouping for targets (like ECS tasks, EC2 instances, IP addresses, or Lambda functions) that are serving
# the same content. When the ALB receives a request on one of its listeners (as defined in the previous explanation), it will forward
# that request to a healthy target within this target group based on load balancing algorithms.
#
# In the context of an ECS cluster, when you define an ECS service, you link it to an ALB target group. The ECS service automatically
# registers and deregisters its tasks (containers) with this target group as they start, stop, or scale, ensuring that the ALB always has
# a list of healthy, available application instances to send traffic to.
resource "aws_alb_target_group" "ecs_service" {
  # Name of the target group aimed to be unique within the AWS region and account they belong to. This value is obtained following a common
  # pattern. If any of these variables change, a new target group with a different name will be created. This can be beneficial for blue/green
  # deployments or when you need to ensure a new target group is deployed when certain application parameters change.
  name                 = "${var.container_name}-${substr(md5(format("%s%s%s", var.container_port, var.deregistration_delay, var.healthcheck_matcher)), 0, 12)}"
  port                 = var.container_port       # Port on which the targets in this target group are listening for traffic forwarded by the ALB
  protocol             = "HTTP"                   # Communication protocol used between the ALB and the targets in this group
  vpc_id               = var.vpc_id               # The targets registered with this target group must reside within this VPC
  target_type          = "ip"                     # Critical for 'awsvpc' aws_ecs_task_definition network mode
  deregistration_delay = var.deregistration_delay # This is the amount seconds for the ALB to wait before completing the deregistration of a target. During this time, the ALB stops sending new requests to the target, but it continues to allow existing in-flight requests to complete. This helps gracefully drain connections from targets that are being stopped or replaced

  health_check {                                  # The health check parameters that the ALB uses to monitor the health of the registered targets. If a target fails the health checks, the ALB stops sending traffic to it until it becomes healthy again
    healthy_threshold   = 2                       # The number of consecutive successful health checks required for a target to be considered healthy
    unhealthy_threshold = 2                       # The number of consecutive successful health checks required for a target to be considered unhealthy
    protocol            = "HTTP"                  # The protocol to use for health checks
    path                = var.health_check_path   # Path used by the ALB to make requests on each target
    interval            = 30                      # Seconds between health checks
    timeout             = 5                       # Maximum time in seconds to wait for a health check response
    matcher             = var.healthcheck_matcher # The expected HTTP response code or codes for a successful health check e.g., 200
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
