# ECS agent IAM role so that ECS can run the task (pull image from ECR, write logs to CloudWatch)
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = file("${path.module}/iam-policies/ecs-task-execution-role-assumption.json")

  tags = {
    Project = var.project_name
  }
}

# Attach the AmazonECSTaskExecutionRolePolicy policy to the ECS agent role
resource "aws_iam_role_policy_attachment" "ecs-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
