# 1. Register the ECS Service as a Scalable Target for Application Auto Scaling
resource "aws_appautoscaling_target" "ecs_target" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  
  # Resource ID is the specific ECS Service ARN
  # resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.image_processor.name}"
  resource_id        = "service/${data.terraform_remote_state.ecs_cluster.outputs.autoscaling_group_name}/${module.ecs_service.ecs_service_name}"
  
  # Set the Task Boundaries
  min_capacity       = var.ecs_task_min_capacity # Minimum tasks running (Low-traffic baseline)
  max_capacity       = var.ecs_task_max_capacity # Maximum tasks allowed (High-traffic safety limit)
}

# 2. Define the Target Tracking Scaling Policy (The CORE of Service Scaling)
resource "aws_appautoscaling_policy" "alb_request_scaling_policy" {
  name                   = "ALB-Requests-Per-Target-Policy"
  service_namespace      = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id            = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension     = aws_appautoscaling_target.ecs_target.scalable_dimension
  policy_type            = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    # Target: Keep the average requests per task at 100/minute
    target_value       = var.target_performance_goal 

    # Cooldown periods for stability
    scale_out_cooldown = 60  # Scale out quickly (1 minute) for responsiveness 
    scale_in_cooldown  = 300 # Scale in slowly (5 minutes) to guarantee response delivery

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget" # Scale out/in strategy
      
      # Link to the specific ALB Target Group
      # resource_label = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.main.arn_suffix}"
      resource_label         = "${data.terraform_remote_state.alb.outputs.alb_arn_suffix}/${data.terraform_remote_state.alb.outputs.alb_target_group_arn_suffix}"
    }
  }
}