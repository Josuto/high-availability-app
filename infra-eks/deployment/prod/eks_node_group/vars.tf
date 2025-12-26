#####################################
# Project Configuration Variables
#####################################

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-course-dummy-nestjs-app"
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be one of: dev, prod."
  }
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform remote state"
  type        = string
}

#####################################
# Node Group Configuration Variables
#####################################

variable "instance_type" {
  description = "EC2 instance type for EKS nodes per environment"
  type        = map(string)
  default = {
    dev  = "t3.small"
    prod = "t3.medium"
  }
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
    dev  = 5
    prod = 10
  }
}

variable "capacity_type" {
  description = "Type of capacity for the node group (ON_DEMAND or SPOT) per environment"
  type        = map(string)
  default = {
    dev  = "SPOT"      # Cost savings for dev
    prod = "ON_DEMAND" # Reliability for production
  }

  validation {
    condition = alltrue([
      for v in values(var.capacity_type) : contains(["ON_DEMAND", "SPOT"], v)
    ])
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}

variable "disk_size" {
  description = "Disk size in GB for worker nodes per environment"
  type        = map(number)
  default = {
    dev  = 20
    prod = 40
  }
}
