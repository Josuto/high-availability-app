# ECS Cluster definition
resource "aws_ecs_cluster" "my-ecs-cluster" {
  name = "my-ecs-cluster"
}

# Launch configuration used by the Auto Scaling Group to create EC2 instances
# Note: Launch configurations do not replace existing EC2 instances; Auto Scaling Groups do
resource "aws_launch_configuration" "my-ecs-launch-config" {
  name_prefix          = "my-ecs-launch-config"
  image_id             = data.aws_ami.ecs-ami-linux-2023.id # Use the latest ECS-optimized AMI for Amazon Linux 2023
  instance_type        = var.ECS_INSTANCE_TYPE
  key_name             = aws_key_pair.my-key-pair.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs-ec2-role.id # The EC2 instance need ECS and ECR access permissions
  security_groups      = [aws_security_group.ecs-security-group.id]
  user_data            = file("${path.module}/ec2-instance-init.sh") # EC2 instance bootstrapping process (includes ECS Cluster join)

  lifecycle {
    create_before_destroy = true # if the launch configuration is updated then create a new launch configuration before destroying the old one to avoid downtime
  }
}

# Auto Scaling Group that manages the EC2 instances
# Note: an option to perform an EC2 instance rolling update when the launch configuration changes is to use the instance_refresh block
resource "aws_autoscaling_group" "my-ecs-autoscaling-group" {
  name                 = "my-ecs-autoscaling-group"
  vpc_zone_identifier  = [aws_subnet.main-public-1.id, aws_subnet.main-public-2.id]
  launch_configuration = aws_launch_configuration.my-ecs-launch-config.name
  min_size             = 1
  max_size             = 2
  tag {
    key                 = "Name"
    value               = "ecs-ec2-container"
    propagate_at_launch = true
  }
}