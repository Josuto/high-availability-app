# ECS Cluster definition
resource "aws_ecs_cluster" "ecs-cluster" {
  name = var.cluster_name
}

# EC2 instance bootstrapping process
locals {
  template = templatefile("${path.module}/templates/ec2-instance-init.tpl", {
    ecs_cluster_name   = var.cluster_name
  })
}

# Launch template used by the Auto Scaling Group to create EC2 instances
# Note: Launch templates do not replace existing EC2 instances; Auto Scaling Groups do
resource "aws_launch_template" "ecs-launch-template" {
  name_prefix   = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.ecs-ami-linux-2023.id # Use the latest ECS-optimized AMI for Amazon Linux 2023
  instance_type = var.ecs_instance_type
  user_data     = base64encode(local.template) # Base64-encoded EC2 instance bootstrapping process

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name # AWS services access permissions
  }

  network_interfaces {
    security_groups = [aws_security_group.cluster.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "ecs-ec2-container"
      Project = var.project_name
    }
  }
}

# Auto Scaling Group that manages the EC2 instances registered at the ECS cluster
resource "aws_autoscaling_group" "ecs-autoscaling-group" {
  name                      = "${var.cluster_name}-ag"
  vpc_zone_identifier       = var.vpc_private_subnets # Instructs the ASG to launch all its instances into the private subnets you defined with the VPC module
  min_size                  = var.instance_min_size
  max_size                  = var.instance_max_size
  health_check_grace_period = 300 # 5 minutes
  health_check_type         = "EC2" # ASG relies on the EC2 instance status checks
  force_delete              = false # Protect against accidental EC2 instance termination (default value)

  launch_template {
    id      = aws_launch_template.ecs-launch-template.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "ecs-ec2-container"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag { # Required for ECS Capacity Provider Managed Scaling to work
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}