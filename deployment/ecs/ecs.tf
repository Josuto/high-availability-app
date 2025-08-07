# ECS Cluster definition
resource "aws_ecs_cluster" "my-ecs-cluster" {
  name = "my-ecs-cluster"
}

# EC2 instance bootstrapping process
locals {
  template = templatefile("templates/ec2-instance-init.tpl", {
    ECS_CLUSTER_NAME   = "my-ecs-cluster"
  })
}

# Launch template used by the Auto Scaling Group to create EC2 instances
# Note: Launch templates do not replace existing EC2 instances; Auto Scaling Groups do
resource "aws_launch_template" "my-ecs-launch-template" {
  name_prefix   = "my-ecs-launch-template"
  image_id      = data.aws_ami.ecs-ami-linux-2023.id # Use the latest ECS-optimized AMI for Amazon Linux 2023
  instance_type = var.ECS_INSTANCE_TYPE
  key_name      = aws_key_pair.my-key-pair.key_name
  user_data     = base64encode(local.template) # Base64-encoded EC2 instance bootstrapping process

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs-ec2-role.name # ECS and ECR access permissions
  }

  network_interfaces {
    security_groups = [aws_security_group.cluster.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-ec2-container"
    }
  }
}

# Auto Scaling Group that manages the EC2 instances
resource "aws_autoscaling_group" "my-ecs-autoscaling-group" {
  name                 = "my-ecs-autoscaling-group"
  vpc_zone_identifier  = module.vpc.private_subnets
  min_size             = 1
  max_size             = 2

  launch_template {
    id      = aws_launch_template.my-ecs-launch-template.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "ecs-ec2-container"
    propagate_at_launch = true
  }
}