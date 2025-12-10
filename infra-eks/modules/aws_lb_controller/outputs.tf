#####################################
# Outputs
#####################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
}

output "service_account_namespace" {
  description = "Namespace of the Kubernetes service account"
  value       = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].namespace
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.aws_load_balancer_controller.name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.aws_load_balancer_controller.namespace
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}

output "helm_release_version" {
  description = "Version of the Helm chart deployed"
  value       = helm_release.aws_load_balancer_controller.version
}
