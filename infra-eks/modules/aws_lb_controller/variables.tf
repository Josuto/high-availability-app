#####################################
# Required Variables
#####################################

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the EKS cluster is deployed"
  type        = string
}

#####################################
# Optional Variables with Defaults
#####################################

variable "namespace" {
  description = "Kubernetes namespace to deploy the controller"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "helm_release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "helm_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.6.0"
}

variable "helm_timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
  default     = 600
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
