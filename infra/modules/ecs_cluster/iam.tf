# ECS EC2 Instance Role:
# This section is composed of the Terraform resources required to create a role for EC2 instances and a policy to 
# enable EC2 registry with an ECS cluster, fetch container images from ECR, and log application data to CloudWatch. 
# Also, it creates an instance profile to associate the role with the EC2 instances.

# IAM role to assume by each EC2 instance running in the ECS cluster
resource "aws_iam_role" "ecs-ec2-role" {
  name               = "ecs-ec2-role"
  assume_role_policy = file("iam-policies/ecs-ec2-role-assumption.json")
}

# IAM role policy to grant the necessary permissions to the ecs-ec2-role to interact with ECS, ECR, and CloudWatch Logs
resource "aws_iam_role_policy" "ecs-ec2-role-policy" {
  name   = "ecs-ec2-role-policy"
  role   = aws_iam_role.ecs-ec2-role.id
  policy = file("iam-policies/ecs-ec2-role-policy.json")
}

# IAM instance profile to allow EC2 instances to access AWS services with the permissions granted by the ecs-ec2-role
resource "aws_iam_instance_profile" "ecs-ec2-role" {
  name = "ecs-ec2-role-instance-profile"
  role = aws_iam_role.ecs-ec2-role.name
}
