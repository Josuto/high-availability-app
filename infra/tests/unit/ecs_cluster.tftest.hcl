# Test suite for ECS Cluster module
# Tests ECS cluster, Auto Scaling Group, Launch Template, and IAM configuration

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "ecs_cluster_basic_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 2
    instance_max_size   = 10
    environment         = "dev"
  }

  # Test ECS cluster is created with correct name
  assert {
    condition     = aws_ecs_cluster.ecs_cluster.name == "dev-test-project-ecs-cluster"
    error_message = "ECS cluster name should match environment and project pattern"
  }
}

run "ecs_asg_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 2
    instance_max_size   = 10
    environment         = "dev"
  }

  # Test ASG min size
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.min_size == 2
    error_message = "ASG min size should match configured value"
  }

  # Test ASG max size
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.max_size == 10
    error_message = "ASG max size should match configured value"
  }

  # Test ASG health check
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.health_check_type == "EC2"
    error_message = "ASG should use EC2 health checks"
  }

  # Test ASG health check grace period
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.health_check_grace_period == 300
    error_message = "ASG health check grace period should be 300 seconds"
  }

  # Test ASG protection for dev environment
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.protect_from_scale_in == false
    error_message = "ASG scale-in protection should be disabled for dev"
  }

  # Test ASG uses private subnets
  assert {
    condition     = length(aws_autoscaling_group.ecs_autoscaling_group.vpc_zone_identifier) == 2
    error_message = "ASG should be deployed in all private subnets"
  }

  # Test AmazonECSManaged tag is present
  assert {
    condition     = contains([for tag in aws_autoscaling_group.ecs_autoscaling_group.tag : tag.key], "AmazonECSManaged")
    error_message = "ASG must have AmazonECSManaged tag for capacity provider"
  }
}

run "ecs_asg_production_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.medium"
    instance_min_size   = 2
    instance_max_size   = 10
    environment         = "prod"
  }

  # Test ASG protection for prod environment
  assert {
    condition     = aws_autoscaling_group.ecs_autoscaling_group.protect_from_scale_in == true
    error_message = "ASG scale-in protection should be enabled for prod"
  }
}

run "ecs_launch_template_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 1
    instance_max_size   = 5
    environment         = "dev"
  }

  # Test launch template instance type
  assert {
    condition     = aws_launch_template.ecs_launch_template.instance_type == "t3.small"
    error_message = "Launch template should use configured instance type"
  }

  # Test launch template uses ECS-optimized AMI
  assert {
    condition     = length(data.aws_ami.ecs_ami_linux_2023.id) > 0
    error_message = "Launch template should use ECS-optimized AMI"
  }

  # Test IMDSv2 is required
  assert {
    condition     = aws_launch_template.ecs_launch_template.metadata_options[0].http_tokens == "required"
    error_message = "Launch template should require IMDSv2 tokens"
  }

  # Test IMDS is enabled
  assert {
    condition     = aws_launch_template.ecs_launch_template.metadata_options[0].http_endpoint == "enabled"
    error_message = "Launch template should have IMDS endpoint enabled"
  }

  # Test IAM instance profile is attached
  assert {
    condition     = length(aws_launch_template.ecs_launch_template.iam_instance_profile) > 0
    error_message = "Launch template should have IAM instance profile"
  }

  # Test security group is attached
  assert {
    condition     = length(aws_launch_template.ecs_launch_template.network_interfaces) > 0
    error_message = "Launch template should have network interface configured"
  }
}

run "ecs_security_group_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 1
    instance_max_size   = 5
    environment         = "dev"
  }

  # Test security group is in correct VPC
  assert {
    condition     = aws_security_group.cluster.vpc_id == "vpc-12345678"
    error_message = "Security group should be in correct VPC"
  }

  # Test egress rule exists
  assert {
    condition     = aws_security_group_rule.cluster_egress.type == "egress"
    error_message = "Security group should have egress rule"
  }

  # Test egress allows all protocols
  assert {
    condition     = aws_security_group_rule.cluster_egress.protocol == "-1"
    error_message = "Security group egress should allow all protocols"
  }
}

run "ecs_iam_configuration" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 1
    instance_max_size   = 5
    environment         = "dev"
  }

  # Test IAM role is created
  assert {
    condition     = length(aws_iam_role.ecs_instance_role.name) > 0
    error_message = "IAM role for ECS instances should be created"
  }

  # Test IAM instance profile is created
  assert {
    condition     = aws_iam_instance_profile.ecs_instance_profile.role == aws_iam_role.ecs_instance_role.name
    error_message = "IAM instance profile should use ECS instance role"
  }

  # Test ECS EC2 policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.ecs_ec2_policy_attachment.role == aws_iam_role.ecs_instance_role.name
    error_message = "ECS EC2 policy should be attached to instance role"
  }

  # Test SSM managed policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.ssm_policy_attachment.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "ECS EC2 role should have SSM policy for management"
  }
}

run "ecs_tags_applied" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.ecs_ami_linux_2023
    values = {
      value = "ami-12345678"
    }
  }

  override_data {
    target = data.aws_ami.ecs_ami_linux_2023
    values = {
      id = "ami-12345678"
    }
  }

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    ecs_instance_type   = "t3.small"
    instance_min_size   = 1
    instance_max_size   = 5
    environment         = "dev"
  }

  # Test ASG tags
  assert {
    condition     = contains([for tag in aws_autoscaling_group.ecs_autoscaling_group.tag : tag.key], "Project")
    error_message = "ASG should have Project tag"
  }

  assert {
    condition     = contains([for tag in aws_autoscaling_group.ecs_autoscaling_group.tag : tag.key], "Environment")
    error_message = "ASG should have Environment tag"
  }
}
