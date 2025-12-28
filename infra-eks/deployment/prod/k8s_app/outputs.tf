#####################################
# Deployment Outputs
#####################################

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = module.k8s_app.deployment_name
}

output "deployment_namespace" {
  description = "Namespace of the Kubernetes deployment"
  value       = module.k8s_app.deployment_namespace
}

output "deployment_replicas" {
  description = "Number of replicas in the deployment"
  value       = module.k8s_app.deployment_replicas
}

#####################################
# Service Outputs
#####################################

output "service_name" {
  description = "Name of the Kubernetes service"
  value       = module.k8s_app.service_name
}

output "service_namespace" {
  description = "Namespace of the Kubernetes service"
  value       = module.k8s_app.service_namespace
}

output "service_type" {
  description = "Type of the Kubernetes service"
  value       = module.k8s_app.service_type
}

#####################################
# Service Account Outputs
#####################################

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = module.k8s_app.service_account_name
}

#####################################
# Ingress Outputs
#####################################

output "ingress_name" {
  description = "Name of the Kubernetes ingress (if enabled)"
  value       = module.k8s_app.ingress_name
}

output "ingress_hostname" {
  description = "Hostname of the ingress load balancer (if enabled)"
  value       = module.k8s_app.ingress_hostname
}

output "alb_url" {
  description = "URL of the Application Load Balancer (if ingress enabled)"
  value       = module.k8s_app.alb_url
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  value       = module.k8s_app.alb_zone_id
}

#####################################
# HPA Outputs
#####################################

output "hpa_name" {
  description = "Name of the Horizontal Pod Autoscaler (if enabled)"
  value       = module.k8s_app.hpa_name
}

output "hpa_min_replicas" {
  description = "Minimum number of replicas for HPA (if enabled)"
  value       = module.k8s_app.hpa_min_replicas
}

output "hpa_max_replicas" {
  description = "Maximum number of replicas for HPA (if enabled)"
  value       = module.k8s_app.hpa_max_replicas
}

#####################################
# Application Configuration Outputs
#####################################

output "container_image" {
  description = "Container image used in the deployment"
  value       = module.k8s_app.container_image
}

output "container_port" {
  description = "Port the container listens on"
  value       = module.k8s_app.container_port
}

output "health_check_path" {
  description = "Health check endpoint path"
  value       = module.k8s_app.health_check_path
}

#####################################
# Access Information
#####################################

output "application_url" {
  description = "Application access URL"
  value       = module.k8s_app.alb_url != null ? module.k8s_app.alb_url : "Application is not exposed via Ingress"
}
