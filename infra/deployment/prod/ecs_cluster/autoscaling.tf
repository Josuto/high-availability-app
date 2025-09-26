# Autoscaling policy that scales up the number of instances in the autoscaling group based on the CPU utilization
resource "aws_autoscaling_policy" "cpu-scale-up-policy" {
  name                   = "cpu-scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # time in which no scale events can happen
  policy_type            = "SimpleScaling" # Add one instance
  autoscaling_group_name = module.ecs_cluster.autoscaling_group_name
}

# CloudWatch alarm that triggers the scale up policy when the CPU utilization exceeds some percentage threshold
resource "aws_cloudwatch_metric_alarm" "cpu-scale-up-alarm" {
  alarm_name          = "cpu-scale-up-alarm"
  alarm_description   = "Trigger an alarm when the CPU utilization exceeds some percentage threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120 # evaluate during 2 minutes
  statistic           = "Average"
  threshold           = var.cpu_scale_up_alarm_thresold
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.cpu-scale-up-policy.arn, aws_sns_topic.autoscaling-alerts-topic.arn]

  dimensions = {
    AutoScalingGroupName = module.ecs_cluster.autoscaling_group_name
  }

  tags = {
    Project = var.project_name
  }
}

# Autoscaling policy that scales down the number of instances in the autoscaling group based on the CPU utilization
resource "aws_autoscaling_policy" "cpu-scale-down-policy" {
  name                   = "cpu-scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # time in which no scale events can happen
  policy_type            = "SimpleScaling" # Add one instance
  autoscaling_group_name = module.ecs_cluster.autoscaling_group_name 
}

# CloudWatch alarm that triggers the scale down policy when the CPU utilization is below some percentage threshold
resource "aws_cloudwatch_metric_alarm" "cpu-scale-down-alarm" {
  alarm_name          = "cpu-scale-down-alarm"
  alarm_description   = "Trigger an alarm when the CPU utilization is below some given percentage threshold"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120 # evaluate during 2 minutes
  statistic           = "Average"
  threshold           = var.cpu_scale_down_alarm_thresold
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.cpu-scale-down-policy.arn, aws_sns_topic.autoscaling-alerts-topic.arn]

  dimensions = {
    AutoScalingGroupName = module.ecs_cluster.autoscaling_group_name
  }

  tags = {
    Project = var.project_name
  }
}

# SNS topic to send notifications
resource "aws_sns_topic" "autoscaling-alerts-topic" {
  name = "${module.ecs_cluster.ecs_cluster_name}-autoscaling-alerts-topic"
  display_name = "Autoscaling Alerts Topic"

  tags = {
    Project = var.project_name
  }
}

# SNS subscription for email notifications
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.autoscaling-alerts-topic.arn
  protocol  = "email"
  endpoint  = var.cpu_alarm_notification_email
}