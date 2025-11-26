output "ecs_service_name" {
  description = "The name of the ECS service running the application"
  value       = module.ecs_service.ecs_service_name
}
