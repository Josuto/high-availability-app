resource "aws_ecs_task_definition" "dummy-app-ecs-task-definition" {
  family                = "dummy-app"
  container_definitions = templatefile("dummy-app-ecs-task-definition-template.json.tpl", {
    ECR_APP_IMAGE = var.ECR_APP_IMAGE
  })
}

resource "aws_ecs_service" "dummy-app-ecs-service" {
  name            = "dummy-app-ecs-service"
  cluster         = aws_ecs_cluster.my-ecs-cluster.id
  task_definition = aws_ecs_task_definition.dummy-app-ecs-task-definition.arn
  desired_count   = 1
  iam_role        = aws_iam_role.ecs-service-role.arn # Role linked to a policy maintained by AWS for ECS services
  depends_on      = [aws_iam_policy_attachment.ecs-service-attach1] # Ensure the IAM policy is attached before creating the service

  load_balancer {
    elb_name       = aws_elb.dummy-app-elb.name
    container_name = var.CONTAINER_NAME # The name of the container in the ECS task definition
    container_port = var.CONTAINER_PORT # The port on the container to associate with the ELB, also defined in the ECS task definition
  }

  lifecycle {
    ignore_changes = [task_definition] # Ignore changes made to the ECS task definition to avoid service disruptions
  }
}