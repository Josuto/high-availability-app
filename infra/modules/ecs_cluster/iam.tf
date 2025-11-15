# ECS EC2 Instance Role:
# This section is composed of the Terraform resources required to create a role for EC2 instances and a policy to 
# enable EC2 registry with an ECS cluster, fetch container images from ECR, and log application data to CloudWatch. 
# Furthermore, the section also includes a policy to enable access to the EC2 instances via SSM from the AWS console.
# Finally, it creates an instance profile to associate the role with the EC2 instances.

# IAM role to assume by each EC2 instance running in the ECS cluster
resource "aws_iam_role" "ecs_instance_role" {
  name               = "ecs_instance_role"
  assume_role_policy = file("${path.module}/iam-policies/ecs-ec2-role-assumption.json")

  tags = {
    Project = var.project_name
  }
}

# IAM role policy to grant the necessary permissions for ECS EC2 instances to interact with ECS, ECR, and CloudWatch Logs
resource "aws_iam_policy" "ecs_ec2_policy" {
  name   = "ecs-ec2-policy"
  policy = file("${path.module}/iam-policies/ecs-ec2-role-policy.json")

  tags = {
    Project = var.project_name
  }
}

# Attach the policy for ECS and ECR access
resource "aws_iam_role_policy_attachment" "ecs_ec2_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = aws_iam_policy.ecs_ec2_policy.arn
}

# Attach the managed policy for SSM access
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM instance profile to allow EC2 instances to access AWS services with all the granted permissions
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

  tags = {
    Project = var.project_name
  }
}
