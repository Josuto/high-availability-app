#####################################
# Deployment Outputs
#####################################

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment.app.metadata[0].name
}

output "deployment_namespace" {
  description = "Namespace of the Kubernetes deployment"
  value       = kubernetes_deployment.app.metadata[0].namespace
}

output "deployment_replicas" {
  description = "Number of replicas in the deployment"
  value       = kubernetes_deployment.app.spec[0].replicas
}

#####################################
# Service Outputs
#####################################

output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.app.metadata[0].name
}

output "service_namespace" {
  description = "Namespace of the Kubernetes service"
  value       = kubernetes_service.app.metadata[0].namespace
}

output "service_type" {
  description = "Type of the Kubernetes service"
  value       = kubernetes_service.app.spec[0].type
}

#####################################
# Service Account Outputs
#####################################

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account.app.metadata[0].name
}

#####################################
# Ingress Outputs
#####################################

output "ingress_name" {
  description = "Name of the Kubernetes ingress (if enabled)"
  value       = var.enable_ingress ? kubernetes_ingress_v1.app[0].metadata[0].name : null
}

output "ingress_hostname" {
  description = "Hostname of the ingress load balancer (if enabled)"
  value = var.enable_ingress && length(kubernetes_ingress_v1.app[0].status) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress) > 0 ? (
    kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress[0].hostname
  ) : null
}

data "aws_elb_hosted_zone_id" "current" {}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  value       = data.aws_elb_hosted_zone_id.current.id
}

output "alb_url" {
  description = "URL of the Application Load Balancer (if ingress enabled and HTTPS)"
  value = var.enable_ingress && var.enable_https && length(kubernetes_ingress_v1.app[0].status) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress) > 0 ? (
    "https://${kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress[0].hostname}"
    ) : (
    var.enable_ingress && length(kubernetes_ingress_v1.app[0].status) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer) > 0 && length(kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress) > 0 ? (
      "http://${kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress[0].hostname}"
    ) : null
  )
}

#####################################
# HPA Outputs
#####################################

output "hpa_name" {
  description = "Name of the Horizontal Pod Autoscaler (if enabled)"
  value       = var.enable_autoscaling ? kubernetes_horizontal_pod_autoscaler_v2.app[0].metadata[0].name : null
}

output "hpa_min_replicas" {
  description = "Minimum number of replicas for HPA (if enabled)"
  value       = var.enable_autoscaling ? kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].min_replicas : null
}

output "hpa_max_replicas" {
  description = "Maximum number of replicas for HPA (if enabled)"
  value       = var.enable_autoscaling ? kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].max_replicas : null
}

#####################################
# Application Configuration Outputs
#####################################

output "container_image" {
  description = "Container image used in the deployment"
  value       = "${var.ecr_repository_url}:${var.image_tag}"
}

output "container_port" {
  description = "Port the container listens on"
  value       = var.container_port
}

output "health_check_path" {
  description = "Health check endpoint path"
  value       = var.health_check_path
}
