############################
# DNS / Domain Configuration
############################

variable "root_domain_name" {
  description = "Fully qualified domain name (FQDN) to associate with the application ALB (e.g. api.example.com)."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID where the DNS record will be created."
  type        = string
  default     = ""
}

############################
# Kubernetes / Ingress Info
############################

variable "namespace" {
  description = "Kubernetes namespace where the ingress resource is deployed."
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Application name used to derive the Kubernetes ingress name and ALB tags."
  type        = string
  default     = "nestjs-app"
}
