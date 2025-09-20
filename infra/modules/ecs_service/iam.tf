# ECS Service Role:
# This section is composed of the Terraform resources required to create a role for the ecs-service ECS service 
# and attach an AWS-managed policy to it. This policy grants the necessary permissions to the ECS service to register 
# tasks and containers, monitor ECS clusters, log activity to CloudWatch Logs, and perform other actions required to manage 
# ECS tasks and services

# IAM role to assume by the ECS service
resource "aws_iam_role" "ecs-service-role" {
  name               = "ecs-service-role"
  assume_role_policy = file("${path.module}/iam-policies/ecs-service-role-assumption.json")
}

# Attach the AmazonEC2ContainerServiceRole policy to the ECS service role
resource "aws_iam_role_policy_attachment" "ecs-service-policy-attachment" {
  role       = aws_iam_role.ecs-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# IAM role policy to enable the ECS service interact with the ALB to describe, register, and desregister targets
resource "aws_iam_policy" "ecs-service-alb-policy" {
  name   = "ecs-service-alb-policy"
  policy = file("${path.module}/iam-policies/ecs-service-alb-ops-role.json")
}

# Attach the policy to enable the ECS service interact with the ALB to the ECS service role
resource "aws_iam_role_policy_attachment" "ecs-service-alb-policy-attachment" {
  role       = aws_iam_role.ecs-service-role.name
  policy_arn = aws_iam_policy.ecs-service-alb-policy.arn
}
