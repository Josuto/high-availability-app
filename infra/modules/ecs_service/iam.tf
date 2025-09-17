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
resource "aws_iam_policy_attachment" "ecs-service-attach1" {
  name       = "ecs-service-attach1"
  roles      = [aws_iam_role.ecs-service-role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
