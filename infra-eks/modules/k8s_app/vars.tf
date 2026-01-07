#####################################
# Project Configuration Variables
#####################################

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

#####################################
# Application Configuration
#####################################

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "nestjs-app"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "default"
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

#####################################
# Deployment Configuration
#####################################

variable "replica_count" {
  description = "Number of pod replicas per environment"
  type        = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}

#####################################
# Resource Configuration
#####################################

variable "memory_request" {
  description = "Memory request per environment"
  type        = map(string)
  default = {
    dev  = "128Mi"
    prod = "512Mi"
  }
}

variable "memory_limit" {
  description = "Memory limit per environment"
  type        = map(string)
  default = {
    dev  = "512Mi"
    prod = "1024Mi"
  }
}

variable "cpu_request" {
  description = "CPU request per environment"
  type        = map(string)
  default = {
    dev  = "50m"
    prod = "250m"
  }
}

variable "cpu_limit" {
  description = "CPU limit per environment"
  type        = map(string)
  default = {
    dev  = "250m"
    prod = "500m"
  }
}

#####################################
# Environment Variables
#####################################

variable "environment_variables" {
  description = "Environment variables for the application"
  type        = map(string)
  default     = {}
}

#####################################
# IAM Configuration
#####################################

variable "iam_role_arn" {
  description = "IAM role ARN for IRSA (IAM Roles for Service Accounts)"
  type        = string
  default     = ""
}

#####################################
# Service Configuration
#####################################

variable "enable_session_affinity" {
  description = "Enable session affinity (sticky sessions)"
  type        = bool
  default     = false
}

#####################################
# Ingress Configuration
#####################################

variable "enable_ingress" {
  description = "Enable Ingress resource creation"
  type        = bool
  default     = true
}

variable "alb_scheme" {
  description = "ALB scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "ALB scheme must be either 'internet-facing' or 'internal'."
  }
}

variable "enable_https" {
  description = "Enable HTTPS on the ALB"
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "additional_ingress_annotations" {
  description = "Additional annotations for the Ingress resource"
  type        = map(string)
  default     = {}
}

variable "root_domain_name" {
  description = "Root domain name for the Ingress resource"
  type        = string
  default     = ""
}

#####################################
# Autoscaling Configuration
#####################################

variable "enable_autoscaling" {
  description = "Enable Horizontal Pod Autoscaler"
  type        = bool
  default     = true
}

variable "min_replicas" {
  description = "Minimum number of replicas for HPA per environment"
  type        = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}

variable "max_replicas" {
  description = "Maximum number of replicas for HPA per environment"
  type        = map(number)
  default = {
    dev  = 5
    prod = 10
  }
}

variable "cpu_target_utilization" {
  description = "Target CPU utilization percentage for HPA"
  type        = number
  default     = 70
}

variable "memory_target_utilization" {
  description = "Target memory utilization percentage for HPA"
  type        = number
  default     = 80
}
