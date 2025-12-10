#####################################
# Outputs
#####################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = module.aws_lb_controller.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  value       = module.aws_lb_controller.oidc_provider_url
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
  value       = module.aws_lb_controller.iam_policy_arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.aws_lb_controller.iam_role_arn
}

output "iam_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = module.aws_lb_controller.iam_role_name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = module.aws_lb_controller.service_account_name
}

output "service_account_namespace" {
  description = "Namespace of the Kubernetes service account"
  value       = module.aws_lb_controller.service_account_namespace
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = module.aws_lb_controller.helm_release_name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release"
  value       = module.aws_lb_controller.helm_release_namespace
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = module.aws_lb_controller.helm_release_status
}

output "helm_release_version" {
  description = "Version of the Helm chart deployed"
  value       = module.aws_lb_controller.helm_release_version
}
