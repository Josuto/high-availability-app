variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "vpc_private_subnets" {
  description = "List of private subnet IDs for the node group"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for the node group"
  type        = string
  default     = "1.28"
}

variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "ami_type" {
  description = "AMI type for worker nodes"
  type        = string
  default     = "AL2_x86_64" # Amazon Linux 2
}

variable "desired_size" {
  description = "Desired number of worker nodes per environment"
  type        = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}

variable "min_size" {
  description = "Minimum number of worker nodes per environment"
  type        = map(number)
  default = {
    dev  = 1
    prod = 2
  }
}

variable "max_size" {
  description = "Maximum number of worker nodes per environment"
  type        = map(number)
  default = {
    dev  = 3
    prod = 10
  }
}

variable "max_unavailable" {
  description = "Maximum number of nodes unavailable during update per environment"
  type        = map(number)
  default = {
    dev  = 1
    prod = 1
  }
}

variable "capacity_type" {
  description = "Type of capacity (ON_DEMAND or SPOT) per environment"
  type        = map(string)
  default = {
    dev  = "SPOT"      # Use spot instances in dev for cost savings
    prod = "ON_DEMAND" # Use on-demand in prod for reliability
  }
}
